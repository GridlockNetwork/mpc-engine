# syntax=docker/dockerfile:1
FROM rust:latest AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    pkg-config \
    libssl-dev \
    autoconf \
    automake \
    libtool \
    make \
    gcc \
    g++ \
    libsodium-dev \
    libgmp-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables for libsodium build
ENV SODIUM_USE_PKG_CONFIG=1

# Copy source code
COPY . .

# Build the application
RUN cargo build --release

# Production stage
FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Gridlock Guardian Node"
LABEL org.opencontainers.image.description="The guardian node is the heart of the Gridlock network. It stores part of a user's private key and works together with other guardian nodes to approve transactions and recover accounts."
LABEL org.opencontainers.image.vendor="Gridlock Network"
LABEL org.opencontainers.image.source="https://github.com/GridlockNetwork/guardian-node"
LABEL org.opencontainers.image.licenses="GPL-3.0"

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates libssl-dev libsodium23 libgmp10 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /app/target/release/guardian-node /app/guardian-node

# Create directories
RUN mkdir -p /var/lib/gridlock/node

# Create startup script to handle config
RUN echo '#!/bin/sh' > /app/start.sh && \
    echo 'if [ -f "/app/.env" ]; then' >> /app/start.sh && \
    echo '  echo "Using mounted .env configuration"' >> /app/start.sh && \
    echo 'else' >> /app/start.sh && \
    echo '  echo "ERROR: No config mounted. Please mount your .env file:"' >> /app/start.sh && \
    echo '  echo "docker run -v /path/to/.env:/app/.env ..."' >> /app/start.sh && \
    echo '  echo "or when using docker-compose, ensure volumes section includes .env mapping"' >> /app/start.sh && \
    echo '  exit 1' >> /app/start.sh && \
    echo 'fi' >> /app/start.sh && \
    echo 'exec "$@"' >> /app/start.sh && \
    chmod +x /app/start.sh

# Expose relevant ports (adjust as needed)
EXPOSE 8080

ENTRYPOINT ["/app/start.sh"]
CMD ["/app/guardian-node"]
