# REW Pi Receiver - ARM Development & Testing Guide

This guide explains how to develop and test the REW Pi Audio Receiver on ARM architecture using local emulation, eliminating the need to deploy to actual Raspberry Pi hardware for every test.

## 🚀 Quick Start

For fast ARM testing, use Docker's ARM emulation:

```bash
./test-arm-docker.sh
```

This will test your ARM container in ~30 seconds and validate:
- ARM architecture compatibility (armv7l)
- Python 3.11 runtime on ARM
- All service endpoints (HTTP status, health, RTP)
- Container functionality

## 🛠️ Development Approaches

### 1. Quick Docker ARM Emulation (Recommended)

**Best for**: Fast development cycles, CI/CD, quick validation

```bash
# Test ARM container with service validation
./test-arm-docker.sh

# Build and test specific changes
docker build --platform linux/arm/v6 -t rew-pi-receiver:latest .
./test-arm-docker.sh
```

**Pros:**
- ✅ Fast (~30 seconds)
- ✅ Tests real service functionality  
- ✅ Validates HTTP/RTP endpoints
- ✅ No additional setup required

**Cons:**
- ⚠️ Limited to containerized environment
- ⚠️ No full Pi OS testing

### 2. Full QEMU ARM Emulation

**Best for**: Complete Pi OS testing, system-level integration

```bash
# One-time setup
./setup-arm-emulation.sh

# Complete image preparation (requires sudo)
cd arm-emulation
sudo ./modify-raspios-image.sh "raspios-lite-armhf.img" "541065216"

# Start ARM Pi emulation
./start-arm-pi.sh

# In another terminal: Deploy container
cd arm-emulation
./deploy-container-to-arm.sh
```

**Pros:**
- ✅ Complete Raspberry Pi OS environment
- ✅ Real systemd, networking, services
- ✅ Full Docker deployment testing
- ✅ SSH access for debugging

**Cons:**
- ⚠️ Slower setup (~10 minutes first time)
- ⚠️ Requires 2.5GB disk space
- ⚠️ Requires sudo for image preparation

## 📁 Repository Structure

```
pi-receiver/
├── test-arm-docker.sh           # Quick ARM testing
├── setup-arm-emulation.sh       # Full QEMU setup
├── arm-emulation/               # QEMU ARM environment (local)
│   ├── start-arm-pi.sh          # Start ARM Pi VM
│   ├── deploy-container-to-arm.sh # Deploy to ARM VM
│   ├── modify-raspios-image.sh  # Prepare Pi OS image
│   ├── raspios-lite-armhf.img   # Pi OS image (2.5GB)
│   └── qemu-rpi-kernel/         # ARM kernels
├── export/                      # Deployment artifacts
│   ├── rew-pi-receiver-*.tar    # ARM container image
│   ├── docker-compose.yaml      # Pi deployment config
│   └── install-from-tarball.sh  # Pi installation script
└── .gitignore                   # Excludes large ARM files
```

## 🔄 Development Workflows

### Quick Development Cycle

```bash
# 1. Make code changes
vim rew_audio_receiver.py

# 2. Test on ARM architecture  
./test-arm-docker.sh

# 3. Build deployment package
./deploy-to-pi.sh build

# 4. Deploy to Pi (when ready)
# Copy export/* to Pi and run install-from-tarball.sh
```

### Complete Testing Cycle

```bash
# 1. Set up ARM emulation (one-time)
./setup-arm-emulation.sh
cd arm-emulation && sudo ./modify-raspios-image.sh "raspios-lite-armhf.img" "541065216"

# 2. Start ARM Pi emulation
./start-arm-pi.sh

# 3. Deploy and test
./deploy-container-to-arm.sh

# 4. SSH into ARM VM for debugging
ssh -p 5022 pi@localhost
```

## 🔧 Troubleshooting

### Docker ARM Emulation Issues

```bash
# Enable ARM emulation support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Check platform support
docker buildx ls

# Force rebuild without cache
docker build --no-cache --platform linux/arm/v6 -t rew-pi-receiver:latest .
```

### QEMU VM Issues

```bash
# Check if VM is running
ps aux | grep qemu-system-arm

# Kill stuck VM
pkill qemu-system-arm

# Check SSH connectivity
ssh -p 5022 -v pi@localhost

# VM console access (if needed)
# In QEMU: Ctrl+A then C for console
```

### Container Issues

```bash
# Check container logs
docker logs rew-arm-test

# Debug container interactively
docker run -it --platform linux/arm/v6 --entrypoint /bin/bash rew-pi-receiver:latest

# Test specific components
docker run --rm --platform linux/arm/v6 rew-pi-receiver:latest --help
```

## 🧪 Testing Scenarios

### 1. Architecture Validation
```bash
# Verify ARM architecture
./test-arm-docker.sh | grep "Architecture:"
# Should show: armv7l or armv6l
```

### 2. Python Runtime Testing
```bash
# Test Python 3.11 on ARM
docker run --rm --platform linux/arm/v6 --entrypoint python rew-pi-receiver:latest --version
# Should show: Python 3.11.x
```

### 3. Service Endpoint Testing  
```bash
# Start container and test endpoints
./test-arm-docker.sh

# Check specific endpoints
curl http://localhost:8080/status
curl http://localhost:8080/health
```

### 4. Full Pi OS Testing
```bash
# Start QEMU Pi emulation
cd arm-emulation && ./start-arm-pi.sh

# In another terminal
ssh -p 5022 pi@localhost 'uname -a'
ssh -p 5022 pi@localhost 'docker --version'
```

## 📝 Expected Test Results

### Quick Docker ARM Test
- ✅ Architecture: `armv7l` 
- ✅ Python: `3.11.13`
- ✅ HTTP Status: `{"status": "running"}`
- ✅ Health Check: `{"status": "healthy"}`
- ✅ RTP Port: Accessible on 5004

### QEMU ARM Test
- ✅ Pi OS: Raspberry Pi OS (ARM)
- ✅ SSH: Accessible on port 5022
- ✅ Docker: Installed and running
- ✅ Container: Deployed and accessible

## 🚨 Known Limitations

### Docker Emulation
- mDNS service unavailable (expected)
- Audio hardware not accessible
- Limited to container environment

### QEMU Emulation  
- Slower than native ARM hardware
- Limited memory (256MB)
- Some Pi-specific hardware features unavailable

## 🔐 Security Notes

- ARM emulation runs with appropriate user privileges
- QEMU VM is isolated from host network by default
- SSH access limited to localhost:5022
- Container runs as non-root user

## 🧹 Cleanup

```bash
# Clean up Docker ARM containers
docker container prune
docker rmi rew-pi-receiver:latest

# Clean up QEMU environment
rm -rf arm-emulation/

# Reset ARM emulation
./setup-arm-emulation.sh  # Will recreate clean environment
```

## 🚀 Performance Tips

1. **Use Docker ARM emulation** for most development
2. **Cache Docker layers** by copying requirements.txt first  
3. **Use .dockerignore** to exclude large files
4. **Run QEMU with SMP** if testing multi-core scenarios
5. **Allocate more memory** to QEMU if needed (edit start-arm-pi.sh)

## 📊 Validation Checklist

Before deploying to real Pi hardware:

- [ ] ARM container builds successfully
- [ ] Python runtime works without errors
- [ ] HTTP endpoints respond correctly
- [ ] Health check returns "healthy"
- [ ] RTP port is accessible
- [ ] Container logs show expected behavior
- [ ] Docker compose configuration valid
- [ ] Deployment scripts executable

## ✅ Quick Validation

Test that everything is working with these commands:

```bash
# 1. Verify ARM container builds
docker build --platform linux/arm/v6 -t rew-pi-receiver:latest .

# 2. Quick ARM functionality test  
./test-arm-docker.sh

# 3. Check build artifacts
./deploy-to-pi.sh build && ls -la export/

# 4. Validate expected results
./test-arm-docker.sh | grep -E "(armv7l|Python 3.11|running|healthy)"
```

Expected output:
- Architecture: `armv7l`
- Python: `3.11.x` 
- Status: `"status": "running"`
- Health: `"status": "healthy"`

## 📚 Additional Resources

- [QEMU ARM Emulation](https://www.qemu.org/docs/master/system/arm/raspi.html)
- [Docker ARM Support](https://docs.docker.com/build/building/multi-platform/)
- [Raspberry Pi OS](https://www.raspberrypi.org/software/operating-systems/)

---

**Next Steps**: Once ARM testing passes, deploy to actual Pi using `export/install-from-tarball.sh`