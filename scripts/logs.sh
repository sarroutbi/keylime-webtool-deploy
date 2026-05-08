#!/bin/sh
# Aggregate logs from all Keylime Monitoring Dashboard containers.
# Usage:
#   scripts/logs.sh              # all services, last 100 lines
#   scripts/logs.sh frontend     # specific service
#   scripts/logs.sh -f           # follow mode (all services)
#   scripts/logs.sh -f backend   # follow specific service
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

FOLLOW=""
SERVICE=""

for arg in "$@"; do
    case "$arg" in
        -f|--follow)
            FOLLOW="--follow"
            ;;
        *)
            SERVICE="${arg}"
            ;;
    esac
done

if [ -n "${SERVICE}" ]; then
    podman-compose logs --tail=100 ${FOLLOW} "${SERVICE}"
else
    podman-compose logs --tail=100 ${FOLLOW}
fi
