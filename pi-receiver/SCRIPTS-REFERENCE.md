# REW Audio Receiver Scripts Reference

This document provides an overview of all available scripts for building, testing, and deploying REW audio receiver containers.

## Main Deployment Scripts

### `deploy-to-pi.sh` - Primary Deployment Tool
**The main deployment script with MediaMTX as default and legacy Python support.**

```bash
./deploy-to-pi.sh [OPTIONS] COMMAND

# Key Commands:
./deploy-to-pi.sh build-pi              # Build ARM MediaMTX container
./deploy-to-pi.sh test-arm               # Test ARM container locally
./deploy-to-pi.sh deploy-remote pi@IP    # Deploy to remote Pi
./deploy-to-pi.sh status                 # Check container status
./deploy-to-pi.sh logs                   # View container logs

# Options:
--mediamtx          # Use MediaMTX container (default)
--legacy            # Use legacy Python container
--platform ARCH     # Target platform (linux/arm/v6, linux/amd64)
--no-cache          # Build without using cache
```

### `deploy-mediamtx-quick.sh` - MediaMTX-Only Tool
**Simplified script focused exclusively on MediaMTX container.**

```bash
./deploy-mediamtx-quick.sh COMMAND [PI_IP]

# Key Commands:
./deploy-mediamtx-quick.sh build        # Build ARM MediaMTX container
./deploy-mediamtx-quick.sh deploy pi@IP # Deploy to Pi
./deploy-mediamtx-quick.sh test-local   # Test with ARM emulation
./deploy-mediamtx-quick.sh status IP    # Check Pi status
./deploy-mediamtx-quick.sh logs IP      # View Pi logs
```

## Build Scripts

### `build-all.sh` - Comprehensive Builder
**Builds all container variants and architectures.**

```bash
./build-all.sh [OPTIONS]

# Options:
--mediamtx-only     # Build only MediaMTX container
--legacy-only       # Build only legacy Python container
--export            # Export ARM images as tarballs
--no-cache          # Build without using cache

# Examples:
./build-all.sh                    # Build both containers (AMD64 + ARM)
./build-all.sh --mediamtx-only    # Build only MediaMTX
./build-all.sh --export           # Build and export for Pi
```

## Test Scripts

### `test-arm-docker.sh` - ARM Emulation Testing
**Tests MediaMTX container using Docker ARM emulation.**

```bash
./test-arm-docker.sh

# Tests performed:
# ✓ ARM architecture compatibility
# ✓ MediaMTX binary functionality
# ✓ API endpoint responses
# ✓ RTP port accessibility
# ✓ Container health and logs
```

### `test-integration-mediamtx.sh` - Pi Integration Testing
**Comprehensive testing on actual Raspberry Pi hardware.**

```bash
./test-integration-mediamtx.sh [PI_IP] [PI_USER]

# Tests performed:
# ✓ Container runtime status
# ✓ MediaMTX API health checks
# ✓ CamillaDSP API availability
# ✓ Network port accessibility
# ✓ Resource usage analysis
# ✓ Audio system integration
```

## Legacy Scripts (Python Container)

### `deploy-mediamtx.sh` - Legacy SystemD Deployment
**⚠️ Deprecated: Old systemd-based deployment for native binaries.**

*Note: This script is kept for reference but superseded by the Docker container approach.*

## Container Approaches

### 🚀 **MediaMTX Container (Recommended)**
- **Image**: `rew-mediamtx-receiver:latest`
- **Dockerfile**: `Dockerfile.mediamtx`  
- **Compose**: `docker-compose.mediamtx.yml`
- **Config**: `.env.mediamtx`
- **Advantages**: No Python timestamp issues, smaller size, faster startup

### 🔄 **Legacy Python Container (Compatibility)**
- **Image**: `rew-pi-receiver:latest`
- **Dockerfile**: `Dockerfile`
- **Compose**: `docker-compose.yaml`  
- **Config**: `.env`
- **Use case**: Fallback for existing deployments

## Quick Reference

### New Project Setup (MediaMTX)
```bash
# 1. Build ARM container
./deploy-to-pi.sh build-pi

# 2. Test locally with ARM emulation  
./deploy-to-pi.sh test-arm

# 3. Deploy to Pi
./deploy-to-pi.sh deploy-remote pi@192.168.1.100

# 4. Verify deployment
./test-integration-mediamtx.sh 192.168.1.100
```

### Legacy Support
```bash
# Use legacy Python container
./deploy-to-pi.sh --legacy build-pi
./deploy-to-pi.sh --legacy deploy-remote pi@192.168.1.100
```

### Build All Variants
```bash
# Build everything
./build-all.sh

# Build and export for Pi deployment
./build-all.sh --export
```

## File Organization

```
pi-receiver/
├── deploy-to-pi.sh              # Main deployment tool
├── deploy-mediamtx-quick.sh     # MediaMTX-focused tool
├── build-all.sh                 # Comprehensive builder
├── test-arm-docker.sh           # ARM emulation testing
├── test-integration-mediamtx.sh # Pi integration testing
├── Dockerfile.mediamtx          # MediaMTX container
├── docker-compose.mediamtx.yml  # MediaMTX orchestration
├── .env.mediamtx               # MediaMTX environment
├── mediamtx-simple.yml         # MediaMTX configuration
├── camilladsp-simple.yml       # CamillaDSP configuration
├── start.sh                    # Container startup script
└── export/                     # ARM image tarballs
```

## Migration Guide

### From Python to MediaMTX
1. **Stop existing Python container**: `docker-compose down`
2. **Build MediaMTX container**: `./deploy-to-pi.sh build-pi`  
3. **Deploy MediaMTX**: `./deploy-to-pi.sh deploy-remote pi@IP`
4. **Update REW settings**: Same RTP endpoint (port 5004)
5. **Test functionality**: `./test-integration-mediamtx.sh PI_IP`

### Key Differences
- **API Port**: MediaMTX uses 9997 (was 8080 for Python)
- **Health Check**: Different endpoint structure
- **Configuration**: YAML files instead of Python config
- **Performance**: Faster startup, lower resource usage

## Troubleshooting

### Common Issues
- **Port conflicts**: Use `netstat -tulpn | grep PORT` to check
- **Architecture mismatch**: Ensure ARM container for Pi deployment  
- **SSH connectivity**: Test with `ssh pi@IP 'echo success'`
- **Docker permissions**: User must be in `docker` group on Pi

### Debug Commands
```bash
# Check container logs
docker logs rew-mediamtx-audio-receiver

# Test API manually
curl http://PI_IP:9997/v3/config

# Check container health
docker ps | grep mediamtx

# Resource usage
docker stats rew-mediamtx-audio-receiver
```

This reference covers all available deployment and testing options for the REW audio receiver project.