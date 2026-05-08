# Multi-stage build: Node.js for building the React SPA, nginx for serving static files.
# The final image contains only the compiled assets and nginx — no Node.js runtime.

# ---------------------------------------------------------------------------
# Stage 1: Build the React application
# ---------------------------------------------------------------------------
FROM docker.io/library/node:20-alpine AS builder

ARG FRONTEND_REPO=https://github.com/keylime-webtool/frontend.git
ARG FRONTEND_REF=main

WORKDIR /build

# When building from a local checkout, use:
#   podman build --build-arg FRONTEND_REPO=. -v ./keylime-webtool-frontend:/build:Z ...
# Otherwise the repo is cloned from the provided URL.
RUN if [ "${FRONTEND_REPO}" = "." ]; then \
        echo "Using bind-mounted source"; \
    else \
        apk add --no-cache git && \
        git clone --depth 1 --branch "${FRONTEND_REF}" "${FRONTEND_REPO}" . ; \
    fi

RUN npm ci --ignore-scripts
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 2: Serve with nginx
# ---------------------------------------------------------------------------
FROM docker.io/library/nginx:1-alpine

ARG BACKEND_HOST=backend
ARG BACKEND_PORT=8080

COPY --from=builder /build/dist /usr/share/nginx/html

# The template is processed at container start by envsubst (via nginx's
# docker-entrypoint) to inject BACKEND_HOST and BACKEND_PORT.
COPY config/nginx.conf.template /etc/nginx/templates/default.conf.template

ENV BACKEND_HOST=${BACKEND_HOST}
ENV BACKEND_PORT=${BACKEND_PORT}

EXPOSE 8443

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO /dev/null --no-check-certificate https://localhost:8443/ || exit 1

USER nginx
