#!/bin/sh
# Build (or rebuild) OCI images for the Keylime Monitoring Dashboard.
# Uses Podman's layer cache for incremental builds.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

# Load .env if present
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

printf "[INFO]  Building frontend image...\n"
podman build \
    -f containers/frontend.containerfile \
    -t "keylime-webtool-frontend:${FRONTEND_IMAGE_TAG:-latest}" \
    --build-arg "BACKEND_HOST=${BACKEND_HOST:-backend}" \
    --build-arg "BACKEND_PORT=${BACKEND_PORT:-8080}" \
    .

printf "[INFO]  Building backend image...\n"
podman build \
    -f containers/backend.containerfile \
    -t "keylime-webtool-backend:${BACKEND_IMAGE_TAG:-latest}" \
    .

printf "[INFO]  Build complete.\n"
podman images --filter "reference=keylime-webtool-*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}"
