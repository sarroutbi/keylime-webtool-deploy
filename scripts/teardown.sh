#!/bin/sh
# Stop and clean up Keylime Monitoring Dashboard services.
# Usage:
#   scripts/teardown.sh             # stop containers, keep volumes
#   scripts/teardown.sh --volumes   # stop containers AND remove volumes
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

REMOVE_VOLUMES=""

for arg in "$@"; do
    case "$arg" in
        --volumes|-v)
            REMOVE_VOLUMES="yes"
            ;;
        *)
            printf "[WARN]  Unknown argument: %s\n" "$arg"
            ;;
    esac
done

printf "[INFO]  Stopping services...\n"
podman-compose down

if [ -n "${REMOVE_VOLUMES}" ]; then
    printf "[INFO]  Removing volumes...\n"
    podman volume rm keylime-webtool-deploy_timescaledb-data 2>/dev/null || true
    podman volume rm keylime-webtool-deploy_redis-data 2>/dev/null || true
    printf "[INFO]  Volumes removed.\n"
fi

printf "[INFO]  Teardown complete.\n"
