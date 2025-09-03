# Multi-stage Dockerfile for REW Pi Audio Receiver
# Supports both x86_64 (local testing) and armv6 (Raspberry Pi) architectures

ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Audio system dependencies
    libasound2-dev \
    portaudio19-dev \
    # Network and system tools
    alsa-utils \
    pulseaudio-utils \
    avahi-daemon \
    avahi-utils \
    # Build dependencies (needed for some Python packages)
    build-essential \
    pkg-config \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r rew && useradd -r -g rew -d /app -s /sbin/nologin rew


# Install Python dependencies with ninja for faster builds
ENV CMAKE_GENERATOR=Ninja
RUN pip install --no-cache-dir --upgrade pip && \
pip install --no-cache-dir --only-binary=:all: wheel setuptools || \
pip install --no-cache-dir wheel setuptools


FROM base AS core

RUN touch /.dockerenv

# Set working directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

RUN pip install --no-cache-dir --prefer-binary -r requirements.txt

# Copy application files
COPY rew_audio_receiver.py .
COPY entrypoint.sh .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create directories for audio output and logs
RUN mkdir -p /tmp/audio /var/log/rew && \
    chown -R rew:rew /app /tmp/audio /var/log/rew

# Switch to non-root user
USER rew

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import socket; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(('0.0.0.0', 5004)); s.close()" || exit 1

# Default environment variables with ARM v6 compatibility
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONHASHSEED=0
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
# ARM v6 specific compatibility settings
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONFAULTHANDLER=1
# Application environment
ENV RTP_PORT=5004
ENV HTTP_PORT=8080
ENV AUDIO_DEVICE=default
ENV LOG_LEVEL=INFO

# Expose ports
EXPOSE 5004/udp 8080/tcp 5353/udp

# Default command
ENTRYPOINT ["./entrypoint.sh"]
CMD ["--device", "default", "--rtp-port", "5004", "--http-port", "8080", "--verbose"]