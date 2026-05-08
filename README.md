# Keylime Monitoring Dashboard — Deployment

Deployment automation for the [Keylime Monitoring Dashboard](https://github.com/keylime-webtool). Containerfiles, Podman Compose, and scripts for plug-and-play provisioning of the frontend, backend, and supporting services.

## Architecture

```
Browser ──TLS 1.3──▶ Reverse Proxy (:8443)
                       ├── /           → Frontend (static files)
                       └── /api/*, /ws → Backend (:8080)
                                          ├── mTLS → Keylime Verifier (:8881)
                                          ├── mTLS → Keylime Registrar (:8891)
                                          ├── TCP  → TimescaleDB (:5432)
                                          └── TCP  → Redis (:6379)
```

| Service      | Image                       | Role                               |
|--------------|-----------------------------|-------------------------------------|
| frontend     | `keylime-webtool-frontend`  | nginx reverse proxy + React SPA     |
| backend      | `keylime-webtool-backend`   | Rust/Axum REST + WebSocket API      |
| timescaledb  | `timescale/timescaledb`     | Attestation event time-series store |
| redis        | `redis:7-alpine`            | Response cache with tiered TTLs     |

## Prerequisites

| Tool             | Minimum Version | Install (Fedora/RHEL)                       |
|------------------|-----------------|----------------------------------------------|
| Podman           | 4.0+            | `sudo dnf install podman`                    |
| podman-compose   | 1.0+            | `pip install podman-compose`                 |
| OpenSSL          | 3.0+            | Installed by default on RHEL 9 / Fedora 40+  |
| Make             | any             | `sudo dnf install make`                      |

## Quick Start

```bash
git clone https://github.com/keylime-webtool/keylime-webtool-deploy.git
cd keylime-webtool-deploy
make setup
```

That single command will:
1. Verify `podman` and `podman-compose` are installed
2. Copy `.env.example` to `.env` (if missing)
3. Generate self-signed TLS certificates (if missing)
4. Build OCI images for the frontend and backend
5. Start all services

The dashboard is then available at **https://localhost:8443**.

## Configuration Reference

All configuration is managed through environment variables in `.env`. See [`.env.example`](.env.example) for the full list with documentation.

| Variable                | Default                         | Description                              |
|-------------------------|---------------------------------|------------------------------------------|
| `HOST_HTTPS_PORT`       | `8443`                          | Host port for the HTTPS frontend         |
| `KEYLIME_VERIFIER_URL`  | `https://localhost:8881`        | Keylime Verifier API endpoint            |
| `KEYLIME_REGISTRAR_URL` | `https://localhost:8891`        | Keylime Registrar API endpoint           |
| `TLS_CERT_PATH`         | `./certs/tls.crt`              | Path to TLS certificate                  |
| `TLS_KEY_PATH`          | `./certs/tls.key`              | Path to TLS private key                  |
| `KEYLIME_CA_CERT`       | `./certs/keylime-ca.crt`       | Keylime CA certificate                   |
| `KEYLIME_CLIENT_CERT`   | `./certs/keylime-client.crt`   | Keylime client certificate               |
| `KEYLIME_CLIENT_KEY`    | `./certs/keylime-client.key`   | Keylime client key                       |
| `POSTGRES_DB`           | `keylime_dashboard`            | TimescaleDB database name                |
| `POSTGRES_USER`         | `keylime`                      | TimescaleDB user                         |
| `POSTGRES_PASSWORD`     | `changeme`                     | TimescaleDB password                     |
| `DATABASE_URL`          | `postgresql://keylime:...`     | Full connection string for the backend   |
| `REDIS_URL`             | `redis://redis:6379`           | Redis connection string                  |
| `RUST_LOG`              | `info`                         | Backend log level                        |

## Make Targets

```
make help       # Show all targets
make setup      # One-command bootstrap
make build      # Build/rebuild OCI images
make up         # Start services
make down       # Stop services (keep data)
make logs       # View logs (ARGS="-f" to follow, ARGS="backend" for one service)
make health     # Check service health
make certs      # Generate self-signed TLS certificates
make clean      # Full reset: stop, remove volumes, images, and certs
```

## Production Deployment

### TLS Certificates

Replace the self-signed certificates with real ones:

```bash
# Edit .env to point to your real certificates
TLS_CERT_PATH=/path/to/production.crt
TLS_KEY_PATH=/path/to/production.key
```

### Keylime mTLS Certificates

Mount the mTLS certificates issued by your Keylime CA:

```bash
KEYLIME_CA_CERT=/path/to/keylime/cacert.crt
KEYLIME_CLIENT_CERT=/path/to/keylime/client.crt
KEYLIME_CLIENT_KEY=/path/to/keylime/client.key
```

### Database Credentials

Set a strong password and update the `DATABASE_URL` to match:

```bash
POSTGRES_PASSWORD=<strong-random-password>
DATABASE_URL=postgresql://keylime:<strong-random-password>@timescaledb:5432/keylime_dashboard
```

### Resource Limits

Add resource limits in a `compose.override.yaml`:

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 512M
  timescaledb:
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 1G
```

## Air-Gapped Deployment

For environments without internet access, pre-build and transfer images as OCI archives.

**On a connected machine:**

```bash
make build
podman save -o keylime-frontend.tar keylime-webtool-frontend:latest
podman save -o keylime-backend.tar keylime-webtool-backend:latest
podman save -o timescaledb.tar docker.io/timescale/timescaledb:latest-pg16
podman save -o redis.tar docker.io/library/redis:7-alpine
```

**Transfer the `.tar` files to the air-gapped host, then:**

```bash
podman load -i keylime-frontend.tar
podman load -i keylime-backend.tar
podman load -i timescaledb.tar
podman load -i redis.tar

cp .env.example .env
# Edit .env with production values
podman-compose up -d
```

## Troubleshooting

**Services won't start:**
```bash
make health          # Check which service is unhealthy
make logs ARGS="backend"   # Check specific service logs
podman ps -a         # Check container states
```

**"Permission denied" on certificate files:**

SELinux may block volume mounts. The compose file uses the `:Z` label, but if issues persist:
```bash
sudo setsebool -P container_manage_cgroup on
```

**TimescaleDB init.sql not applied:**

The init script only runs on first container start. To re-initialize:
```bash
make clean           # Removes volumes
make up              # Fresh start with init.sql
```

**Port 8443 already in use:**

Change `HOST_HTTPS_PORT` in `.env`:
```bash
HOST_HTTPS_PORT=9443
make up
```

**Frontend shows "502 Bad Gateway":**

The backend hasn't finished starting. Check its health:
```bash
make health
make logs ARGS="backend"
```

## License

Apache-2.0 — see [LICENSE](LICENSE).
