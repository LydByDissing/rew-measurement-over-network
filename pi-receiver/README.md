# REW Pi Audio Receiver - Docker Deployment

## Overview

The REW Pi Audio Receiver Docker container eliminates compilation issues and provides an easy deployment method for Raspberry Pi devices. This containerized solution works both locally (x86) for testing and on Raspberry Pi hardware (ARM) for production.

## Quick Start

### For Raspberry Pi Deployment

1. **Copy files to Pi:**
   ```bash
   scp -r pi-receiver/ pi@your-pi-ip:~/rew-receiver/
   ```

2. **Deploy on Pi:**
   ```bash
   ssh pi@your-pi-ip
   cd ~/rew-receiver
   ./deploy-to-pi.sh build-pi
   ./deploy-to-pi.sh deploy
   ```

### For Local Testing (x86)

```bash
cd pi-receiver
./deploy-to-pi.sh build
./deploy-to-pi.sh deploy
```

## Container Features

### ✅ **Solved Problems:**
- **No more compilation issues** - All dependencies pre-built in container
- **Easy deployment** - Single command deployment to Pi
- **Consistent environment** - Same container works locally and on Pi
- **Auto-recovery** - Container restarts on failure
- **Health monitoring** - Built-in health checks and status API

### 🎵 **Audio Capabilities:**
- **ALSA audio output** with configurable devices
- **PulseAudio support** via socket mounting
- **Null device support** for testing
- **48kHz, 16-bit stereo** audio streaming

### 📡 **Network Features:**
- **RTP audio streaming** on port 5004 (configurable)
- **HTTP status API** on port 8080 (configurable) 
- **mDNS service discovery** for automatic detection
- **Connection quality monitoring**

## Configuration

### Environment File (.env)

Copy `.env.example` to `.env` and customize:

```bash
# Pi identification
PI_HOSTNAME=rew-pi-kitchen
VERSION=latest

# Audio configuration  
AUDIO_DEVICE=hw:0,0          # Use specific hardware device
# AUDIO_DEVICE=pulse         # Use PulseAudio
# AUDIO_DEVICE=default       # Use system default

# Network ports
RTP_PORT=5004                # RTP audio streaming port
HTTP_PORT=8080               # HTTP status/API port

# Logging
LOG_LEVEL=INFO               # DEBUG, INFO, WARNING, ERROR

# Container resource limits (adjust for Pi model)
# Pi Zero/1: memory: 128M, cpus: '0.5'
# Pi 2/3:    memory: 256M, cpus: '1.0' 
# Pi 4/5:    memory: 512M, cpus: '2.0'
```

## Deployment Script Usage

The `deploy-to-pi.sh` script provides comprehensive container management:

### Build Commands
```bash
./deploy-to-pi.sh build      # Build x86 image for local testing
./deploy-to-pi.sh build-pi   # Build ARM image for Raspberry Pi  
```

### Deployment Commands
```bash
./deploy-to-pi.sh deploy                    # Deploy locally
./deploy-to-pi.sh deploy-remote pi@ip       # Deploy to remote Pi via SSH
```

### Management Commands  
```bash
./deploy-to-pi.sh start      # Start container
./deploy-to-pi.sh stop       # Stop container
./deploy-to-pi.sh status     # Show container status
./deploy-to-pi.sh logs       # Show container logs
./deploy-to-pi.sh clean      # Remove container and images
```

## Docker Compose Setup

### Basic docker-compose.yaml
The container uses host networking for optimal audio and mDNS performance:

```yaml
services:
  rew-pi-receiver:
    image: rew-pi-receiver:latest
    container_name: rew-pi-audio-receiver
    network_mode: host
    restart: unless-stopped
    
    environment:
      - AUDIO_DEVICE=default
      - RTP_PORT=5004
      - HTTP_PORT=8080
      - LOG_LEVEL=INFO
    
    volumes:
      - /dev/snd:/dev/snd               # Audio device access
      - /run/pulse:/run/pulse:ro        # PulseAudio socket
      - ./logs:/var/log/rew             # Log persistence
    
    devices:
      - /dev/snd                        # Audio device access
    
    cap_add:
      - DAC_OVERRIDE                    # Audio permissions
```

### With System Monitoring
Enable the monitoring profile:

```bash
COMPOSE_PROFILES=monitoring docker-compose up -d
```

This adds a Prometheus node exporter on port 9100 for system metrics.

## Container Architecture

### Multi-Architecture Support
- **linux/amd64** - Local development and testing
- **linux/arm/v6** - Raspberry Pi Zero, Pi 1
- **linux/arm/v7** - Raspberry Pi 2, Pi 3
- **linux/arm64** - Raspberry Pi 4, Pi 5 (64-bit OS)

### Container Contents
- **Python 3.12** runtime environment
- **ALSA** and **PulseAudio** audio libraries
- **Avahi** for mDNS service discovery
- **Audio dependencies** (portaudio, pyalsaaudio, etc.)
- **Enhanced entrypoint** with initialization and monitoring

## Status API Endpoints

The container exposes HTTP endpoints for monitoring:

### GET /status
```json
{
  "service": "REW Audio Receiver",
  "version": "1.0.0", 
  "status": "running",
  "audio": {
    "device": "hw:0,0",
    "port": 5004,
    "running": true
  },
  "stats": {
    "packets_received": 1250,
    "bytes_received": 2560000,
    "errors": 0,
    "connection_errors": 0,
    "connection_status": "GOOD"
  }
}
```

### GET /health
```json
{
  "status": "healthy",
  "timestamp": 1693789234
}
```

## Integration with Java Audio Bridge

### Network Discovery
The Pi receiver advertises itself via mDNS as:
- **Service Name**: `REW-Pi-{hostname}._rew-audio._tcp.local.`  
- **Port**: 5004 (or configured RTP_PORT)
- **HTTP API**: Port 8080 (or configured HTTP_PORT)

### Audio Flow
1. **Desktop side**: Java Audio Bridge captures from REW via PulseAudio loopback
2. **Network**: RTP stream sent to Pi receiver on port 5004
3. **Pi side**: Container receives RTP packets and outputs to ALSA audio device

## Troubleshooting

### Common Issues

#### 1. Audio Device Access
```bash
# Check available audio devices
docker exec rew-pi-audio-receiver aplay -l

# Test with null device first
docker-compose run --rm rew-pi-receiver --device null --verbose
```

#### 2. PulseAudio Connection
```bash
# Mount PulseAudio socket correctly
ls -la /run/pulse/native  # Should exist

# Or use ALSA directly
AUDIO_DEVICE=hw:0,0 docker-compose up
```

#### 3. Network Connectivity
```bash
# Test RTP port access
nc -u pi-ip 5004

# Check status API
curl http://pi-ip:8080/status
```

#### 4. Container Logs
```bash
# View real-time logs
./deploy-to-pi.sh logs

# Or with docker-compose
docker-compose logs -f
```

### Performance Tuning

#### For Pi Zero/1 (limited resources):
```yaml
deploy:
  resources:
    limits:
      memory: 128M
      cpus: '0.5'
environment:
  - LOG_LEVEL=WARNING  # Reduce logging overhead
```

#### For Pi 4/5 (more resources):
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '2.0'  
environment:
  - LOG_LEVEL=DEBUG    # Detailed logging available
```

## Development Workflow

### 1. Local Development
```bash
# Test container locally first
./deploy-to-pi.sh build
./deploy-to-pi.sh deploy

# Verify functionality  
curl http://localhost:8080/status
```

### 2. Pi Testing
```bash
# Build ARM version
./deploy-to-pi.sh build-pi

# Deploy to Pi
./deploy-to-pi.sh deploy-remote pi@192.168.1.100
```

### 3. Integration Testing
```bash
# Use existing Docker Compose test environment
cd ../
./test-docker-setup.sh
```

This runs the full Java Bridge + Pi receiver integration test with containers.

## Production Deployment

### Systemd Integration (Optional)
The container includes systemd service generation:

```bash
# Generate systemd service
docker run --rm rew-pi-receiver:latest --generate-systemd > /etc/systemd/system/rew-pi-receiver.service

# Enable and start
sudo systemctl enable rew-pi-receiver.service
sudo systemctl start rew-pi-receiver.service
```

### Auto-Updates
Set up automatic container updates:

```bash
# Add to crontab
0 2 * * * cd /home/pi/rew-receiver && ./deploy-to-pi.sh build-pi && docker-compose up -d
```

## Success Metrics

With this Docker solution, you now have:

- ✅ **Zero compilation** on Pi devices
- ✅ **One-command deployment** via `deploy-to-pi.sh`
- ✅ **Consistent testing** environment (local x86 + Pi ARM)  
- ✅ **Automatic recovery** and health monitoring
- ✅ **Easy configuration** via environment variables
- ✅ **Production ready** with resource limits and logging

The Pi receiver is now ready for easy distribution and deployment! 🎉