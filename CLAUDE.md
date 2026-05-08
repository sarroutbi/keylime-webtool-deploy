# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

Deployment automation for the Keylime Monitoring Dashboard. It provides Containerfiles, Podman Compose orchestration, and shell scripts to build, configure, and run the full application stack. This repo contains **no application source code** — it consumes the frontend and backend as OCI images built from their respective repositories.

## Architecture

```
Browser ──TLS 1.3──▶ nginx reverse proxy (:8443)
                       ├── /           → static SPA files (baked into frontend image)
                       └── /api/*, /ws → backend (:8080)
                                          ├── mTLS → Keylime Verifier
                                          ├── mTLS → Keylime Registrar
                                          ├── TCP  → TimescaleDB
                                          └── TCP  → Redis
```

Only the frontend container is exposed to the host network. All inter-service communication flows over the internal `internal` bridge network defined in `compose.yaml`.

## Key Commands

```bash
make setup      # Full bootstrap: prereqs, certs, build, start
make build      # Rebuild OCI images (uses Podman layer cache)
make up         # Start all services (podman-compose up -d)
make down       # Stop services, keep volumes
make health     # Check health of all four services
make logs       # Aggregated logs (ARGS="-f" to follow, ARGS="backend" for one service)
make certs      # Regenerate self-signed TLS certificates
make clean      # Full teardown: stop, remove volumes, images, and certs
```

## File Layout

- `containers/frontend.containerfile` — Multi-stage: Node.js build, nginx:alpine runtime. Processes `config/nginx.conf.template` via envsubst at startup.
- `containers/backend.containerfile` — Multi-stage: Rust builder, debian-slim runtime with single binary.
- `compose.yaml` — Podman Compose v1.x service definitions with health checks, dependency ordering, and SELinux-compatible volume labels (`:Z`).
- `config/nginx.conf.template` — nginx config with TLS 1.3, reverse proxy for `/api/*` and `/ws`, security headers (HSTS, CSP, X-Frame-Options). Uses `$BACKEND_HOST` and `$BACKEND_PORT` envsubst variables.
- `config/timescaledb/init.sql` — Creates `attestation_events` hypertable, `agent_snapshots` table, indexes, and a 90-day retention policy. Only runs on first container start.
- `.env.example` — Documented template for all environment variables with dev defaults.
- `scripts/` — POSIX sh scripts (setup, build, teardown, health, logs). Must remain compatible with RHEL 9 / Fedora 40+.

## Constraints

- **Podman-only** — never use `docker` or `Dockerfile` naming. Use `podman`, `podman-compose`, and `Containerfile`.
- **No `--privileged`** — all containers run rootless.
- **Air-gapped support** — no runtime internet access. All assets must be self-contained in OCI images. No external CDN references.
- **TLS 1.3 minimum** for browser-facing connections. mTLS for Keylime API communication.
- **Secrets via env vars or mounted files** — never bake credentials into images.
- **podman-compose v1.x compatibility** — avoid Docker Compose v2-only features.
- **SELinux** — volume mounts use the `:Z` label for proper context labeling.
- `.env` and `certs/` are gitignored — never commit secrets or generated certificates.
