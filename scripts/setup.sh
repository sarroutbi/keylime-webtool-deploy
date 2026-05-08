#!/bin/sh
# One-command bootstrap for the Keylime Monitoring Dashboard.
# Validates prerequisites, generates self-signed TLS certs if missing,
# copies .env.example if needed, builds images, and starts all services.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Colors (if terminal supports them) ---
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; exit 1; }

# --- Prerequisite checks ---
check_command() {
    command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not found. Install it and try again."
}

info "Checking prerequisites..."
check_command podman
check_command podman-compose

PODMAN_VERSION=$(podman --version | grep -oE '[0-9]+\.[0-9]+')
info "podman version: ${PODMAN_VERSION}"

COMPOSE_VERSION=$(podman-compose --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
info "podman-compose version: ${COMPOSE_VERSION}"

# --- .env ---
if [ ! -f "${PROJECT_DIR}/.env" ]; then
    info "Copying .env.example to .env"
    cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
    warn "Review .env and adjust settings before production use."
fi

# --- TLS certificates ---
CERT_DIR="${PROJECT_DIR}/certs"
mkdir -p "${CERT_DIR}"

if [ ! -f "${CERT_DIR}/tls.crt" ] || [ ! -f "${CERT_DIR}/tls.key" ]; then
    info "Generating self-signed TLS certificate..."
    check_command openssl
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -days 365 \
        -keyout "${CERT_DIR}/tls.key" \
        -out "${CERT_DIR}/tls.crt" \
        -subj "/CN=keylime-dashboard/O=Development" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
        2>/dev/null
    info "Self-signed TLS certificate created at ${CERT_DIR}/"
fi

# --- Placeholder Keylime mTLS certs (dev only) ---
for CERT_FILE in keylime-ca.crt keylime-client.crt keylime-client.key; do
    if [ ! -f "${CERT_DIR}/${CERT_FILE}" ]; then
        warn "Creating placeholder ${CERT_FILE} (replace with real certs for production)"
        openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -days 365 \
            -keyout "${CERT_DIR}/keylime-client.key" \
            -out "${CERT_DIR}/keylime-client.crt" \
            -subj "/CN=keylime-client/O=Development" \
            2>/dev/null
        cp "${CERT_DIR}/keylime-client.crt" "${CERT_DIR}/keylime-ca.crt"
        break
    fi
done

# --- Build images ---
info "Building container images..."
"${SCRIPT_DIR}/build.sh"

# --- Start services ---
info "Starting services..."
cd "${PROJECT_DIR}"
podman-compose up -d

info "Setup complete. Dashboard available at https://localhost:${HOST_HTTPS_PORT:-8443}"
info "Run 'make health' to check service status."
