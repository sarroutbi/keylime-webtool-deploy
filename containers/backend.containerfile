# Multi-stage build: Rust toolchain for compilation, minimal runtime image.
# The final image contains only the statically-linked binary — no compiler.

# ---------------------------------------------------------------------------
# Stage 1: Build the Rust backend
# ---------------------------------------------------------------------------
FROM docker.io/library/rust:1-slim-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        pkg-config libssl-dev git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG BACKEND_REPO=https://github.com/keylime-webtool/backend.git
ARG BACKEND_REF=main

WORKDIR /build

# Support both cloned and bind-mounted sources (same pattern as frontend).
RUN if [ "${BACKEND_REPO}" = "." ]; then \
        echo "Using bind-mounted source"; \
    else \
        git clone --depth 1 --branch "${BACKEND_REF}" "${BACKEND_REPO}" . ; \
    fi

RUN cargo build --release && \
    strip target/release/keylime-webtool-backend

# ---------------------------------------------------------------------------
# Stage 2: Minimal runtime
# ---------------------------------------------------------------------------
FROM docker.io/library/debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates libssl3 curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system app && useradd --system --gid app --create-home app

COPY --from=builder /build/target/release/keylime-webtool-backend /usr/local/bin/

ENV RUST_LOG=info
ENV LISTEN_ADDR=0.0.0.0:8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost:8080/api/health || exit 1

USER app

ENTRYPOINT ["keylime-webtool-backend"]
