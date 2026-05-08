#!/bin/sh
# Check health of all Keylime Monitoring Dashboard services.
set -eu

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

EXIT_CODE=0

check_container() {
    name="$1"
    container="$2"

    status=$(podman inspect --format '{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "not found")

    case "${status}" in
        healthy)
            printf "${GREEN}[OK]${NC}     %-20s %s\n" "${name}" "${status}"
            ;;
        starting)
            printf "${YELLOW}[WAIT]${NC}   %-20s %s\n" "${name}" "${status}"
            ;;
        *)
            printf "${RED}[FAIL]${NC}   %-20s %s\n" "${name}" "${status}"
            EXIT_CODE=1
            ;;
    esac
}

printf "Service Health Check\n"
printf "====================\n"

check_container "Frontend"    "keylime-frontend"
check_container "Backend"     "keylime-backend"
check_container "TimescaleDB" "keylime-timescaledb"
check_container "Redis"       "keylime-redis"

printf "\n"

if [ "${EXIT_CODE}" -eq 0 ]; then
    printf '%sAll services healthy.%s\n' "${GREEN}" "${NC}"
else
    printf '%sSome services are unhealthy. Run '\''make logs'\'' for details.%s\n' "${RED}" "${NC}"
fi

exit "${EXIT_CODE}"
