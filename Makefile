.PHONY: setup build up down logs health clean certs

setup: ## One-command bootstrap: prereqs, certs, build, start
	@bash scripts/setup.sh

build: ## Build or rebuild OCI images
	@bash scripts/build.sh

up: ## Start all services and check health
	@podman-compose up -d
	@sleep 5
	@bash scripts/health.sh
	@printf "\nDashboard: https://127.0.0.1:%s\n" "$${HOST_HTTPS_PORT:-8443}"

down: ## Stop all services (keep volumes)
	@podman-compose down

logs: ## Show aggregated logs (use ARGS="-f" to follow, ARGS="backend" for a service)
	@bash scripts/logs.sh $(ARGS)

health: ## Check health of all services
	@bash scripts/health.sh

clean: ## Stop services and remove volumes, images, and generated certs
	@bash scripts/teardown.sh --volumes
	@podman rmi keylime-webtool-frontend:latest keylime-webtool-backend:latest 2>/dev/null || true
	@rm -rf certs/
	@printf "[INFO]  Clean complete.\n"

certs: ## Generate self-signed TLS certificates
	@mkdir -p certs
	@openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
		-days 365 \
		-keyout certs/tls.key \
		-out certs/tls.crt \
		-subj "/CN=keylime-dashboard/O=Development" \
		-addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
		2>/dev/null
	@chmod 644 certs/tls.key
	@printf "[INFO]  Self-signed TLS certificate generated in certs/\n"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
