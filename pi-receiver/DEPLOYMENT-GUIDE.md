# REW MediaMTX Audio Receiver - Quick Deployment Guide

This guide covers deploying the MediaMTX + CamillaDSP Docker container to a Raspberry Pi.

## Prerequisites

- **Development Machine**: Docker with buildx support
- **Raspberry Pi**: Docker installed, SSH access
- **Network**: Both machines on same network

## Quick Deployment Steps

### 1. Build ARM Container

```bash
# Build ARM v6 container (Pi Zero/1) 
docker buildx build --platform linux/arm/v6 -f Dockerfile.mediamtx -t rew-mediamtx-receiver:arm --load .

# For Pi 4+ use ARM v7
docker buildx build --platform linux/arm/v7 -f Dockerfile.mediamtx -t rew-mediamtx-receiver:arm --load .
```

### 2. Export and Transfer

```bash
# Export container
docker save rew-mediamtx-receiver:arm -o rew-mediamtx-receiver.tar

# Create deployment directory on Pi
ssh pi@PI_IP "mkdir -p ~/rew-mediamtx"

# Copy files to Pi
scp rew-mediamtx-receiver.tar docker-compose.mediamtx.yml .env.mediamtx pi@PI_IP:~/rew-mediamtx/
```

### 3. Deploy on Pi

```bash
# Load container image
ssh pi@PI_IP "cd ~/rew-mediamtx && docker load -i rew-mediamtx-receiver.tar"

# Start container
ssh pi@PI_IP "cd ~/rew-mediamtx && docker-compose -f docker-compose.mediamtx.yml --env-file .env.mediamtx up -d"
```

### 4. Verify Deployment

```bash
# Check container status
ssh pi@PI_IP "docker ps | grep mediamtx"

# Test MediaMTX API
curl http://PI_IP:9997/v3/config

# Run integration tests
./test-integration-mediamtx.sh PI_IP
```

## One-Command Deployment

Use the existing deploy script for automated deployment:

```bash
./deploy-to-pi.sh deploy-remote pi@PI_IP
```

## REW Configuration

Once deployed, configure REW:

1. **Output**: Audio Device → Network/RTP
2. **Target**: `PI_IP:5004` 
3. **Timeout**: 5000ms
4. **Format**: 16-bit, 48kHz

## Troubleshooting

### Container Won't Start
```bash
# Check logs
ssh pi@PI_IP "docker logs rew-mediamtx-audio-receiver"

# Check if ports are in use
ssh pi@PI_IP "sudo netstat -tulpn | grep -E ':(9997|8554|5004|1234)'"
```

### No Audio Output
```bash
# Check ALSA devices
ssh pi@PI_IP "docker exec rew-mediamtx-audio-receiver aplay -l"

# Test audio
ssh pi@PI_IP "docker exec rew-mediamtx-audio-receiver speaker-test -c2 -t sine"
```

### API Not Responding
```bash
# Test MediaMTX API
curl http://PI_IP:9997/v3/config

# Test CamillaDSP API (if enabled)
curl http://PI_IP:1234/api/v1/state
```

## Management Commands

```bash
# View logs
ssh pi@PI_IP "docker logs rew-mediamtx-audio-receiver -f"

# Restart container
ssh pi@PI_IP "docker restart rew-mediamtx-audio-receiver"

# Stop container
ssh pi@PI_IP "cd ~/rew-mediamtx && docker-compose -f docker-compose.mediamtx.yml down"

# Update container
# 1. Build new image on development machine
# 2. Export and transfer as above
# 3. Load new image: docker load -i rew-mediamtx-receiver.tar
# 4. Restart: docker-compose ... up -d --force-recreate
```

## Files Overview

- **`Dockerfile.mediamtx`**: Container definition
- **`docker-compose.mediamtx.yml`**: Container orchestration  
- **`.env.mediamtx`**: Environment configuration
- **`mediamtx-simple.yml`**: MediaMTX configuration
- **`camilladsp-simple.yml`**: CamillaDSP configuration
- **`start.sh`**: Container startup script

## Next Steps

1. Test with REW measurement
2. Configure CamillaDSP filters if needed
3. Set up monitoring/alerting
4. Create backup/restore procedures

For detailed information, see `README-MediaMTX.md`.