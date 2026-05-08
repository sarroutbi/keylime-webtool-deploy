# Multi-stage build: Rust toolchain for compilation, minimal Fedora runtime image.
# The final image contains only the compiled binary — no compiler.

# ---------------------------------------------------------------------------
# Stage 1: Build the Rust backend
# ---------------------------------------------------------------------------
FROM registry.fedoraproject.org/fedora:43 AS builder

RUN dnf install -y --setopt=install_weak_deps=False \
        rust cargo pkg-config openssl-devel git ca-certificates \
    && dnf clean all

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
FROM registry.fedoraproject.org/fedora-minimal:43

RUN microdnf install -y --setopt=install_weak_deps=0 \
        ca-certificates openssl-libs curl shadow-utils \
    && microdnf clean all

RUN groupadd --system app && useradd --system --gid app --create-home app

COPY --from=builder /build/target/release/keylime-webtool-backend /usr/local/bin/

ENV RUST_LOG=info
ENV LISTEN_ADDR=0.0.0.0:8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -so /dev/null -w '' http://localhost:8080/ || exit 1

USER app

ENTRYPOINT ["keylime-webtool-backend"]
