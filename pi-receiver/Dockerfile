# Dockerfile for REW MediaMTX + CamillaDSP Audio Receiver
# Using Alpine with glibc compatibility for CamillaDSP

FROM alpine:3.18

# Install glibc compatibility and runtime dependencies
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
    libstdc++

# Create app user
RUN addgroup -g 1000 rew && adduser -u 1000 -G rew -s /bin/sh -D rew

# Create directories
RUN mkdir -p /app/config /app/logs /tmp/audio && \
    chown -R rew:rew /app /tmp/audio

# Download binaries based on architecture
ARG TARGETARCH
ARG MEDIAMTX_VERSION=v1.12.3
ARG CAMILLADSP_VERSION=v3.0.1

WORKDIR /tmp

# Download and install MediaMTX
RUN case ${TARGETARCH:-amd64} in \
    amd64) ARCH="amd64" ;; \
    arm) ARCH="armv6" ;; \
    arm64) ARCH="arm64v8" ;; \
    *) ARCH="amd64" ;; \
    esac && \
    wget -O mediamtx.tar.gz "https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_${ARCH}.tar.gz" && \
    tar xzf mediamtx.tar.gz && \
    cp mediamtx /usr/local/bin/ && \
    chmod +x /usr/local/bin/mediamtx

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
COPY mediamtx.yml /app/config/mediamtx.yml
COPY camilladsp.yml /app/config/camilladsp.yml

# Copy startup script and audio test utility
COPY start.sh /app/start.sh
COPY test-audio.sh /app/test-audio.sh

RUN chmod +x /app/start.sh /app/test-audio.sh && chown -R rew:rew /app

# Switch to app user
USER rew
WORKDIR /app

# Expose ports
EXPOSE 8554/tcp 9997/tcp 1234/tcp 5004/udp 8000/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:9997/v3/config || exit 1

# Use tini for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./start.sh"]