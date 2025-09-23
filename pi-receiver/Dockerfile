# Dockerfile for REW Audio Receiver with CamillaDSP + RTP/UDP bridges
# Using Alpine with glibc compatibility for CamillaDSP

FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    alsa-lib \
    alsa-utils \
    ffmpeg \
    ca-certificates \
    tzdata \
    tini \
    wget \
    curl \
    net-tools \
    gcompat \
    libstdc++ \
    bash

# Create app user
RUN addgroup -g 1000 rew && adduser -u 1000 -G rew -s /bin/bash -D rew

# Create directories
RUN mkdir -p /app/config /app/logs /tmp/audio && \
    chown -R rew:rew /app /tmp/audio

# Download binaries based on architecture
ARG TARGETARCH
ARG CAMILLADSP_VERSION=v3.0.1

WORKDIR /tmp

# Download and install CamillaDSP with glibc compatibility
RUN case ${TARGETARCH:-amd64} in \
    amd64) ARCH="amd64" ;; \
    arm) ARCH="armv6" ;; \
    arm64) ARCH="aarch64" ;; \
    *) ARCH="amd64" ;; \
    esac && \
    wget -O camilladsp.tar.gz "https://github.com/HEnquist/camilladsp/releases/download/${CAMILLADSP_VERSION}/camilladsp-linux-${ARCH}.tar.gz" && \
    tar xzf camilladsp.tar.gz && \
    cp camilladsp /usr/local/bin/ && \
    chmod +x /usr/local/bin/camilladsp && \
    rm -f camilladsp.tar.gz

# Copy configuration files
COPY camilladsp.yml /app/config/camilladsp.yml

# Copy bridge scripts and utilities
COPY rtp-to-alsa.sh /app/rtp-to-alsa.sh
COPY udp-to-alsa.sh /app/udp-to-alsa.sh
COPY start.sh /app/start.sh
COPY test-audio.sh /app/test-audio.sh

RUN chmod +x /app/*.sh && chown -R rew:rew /app

# Switch to app user
USER rew
WORKDIR /app

# Expose ports
EXPOSE 1234/tcp 8000/udp 5004/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:1234/api/config || exit 1

# Use tini for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./start.sh"]
