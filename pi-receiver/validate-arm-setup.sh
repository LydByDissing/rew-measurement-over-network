#!/bin/bash
#
# ARM Development Environment Validation Script
# Tests all documented functionality to ensure it works correctly
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[VALIDATE]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🧪 ARM Development Environment Validation"
echo "========================================"
echo ""

# Test 1: Docker ARM Platform Support
log "Test 1: Checking Docker ARM platform support..."
if docker buildx ls | grep -q "linux/arm"; then
    success "Docker ARM emulation available"
else
    error "Docker ARM emulation not available"
    echo "Run: docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
    exit 1
fi

# Test 2: ARM Container Build
log "Test 2: Testing ARM container build..."
if docker build --platform linux/arm/v6 -t rew-pi-receiver:latest . > /dev/null 2>&1; then
    success "ARM container builds successfully"
else
    error "ARM container build failed"
    exit 1
fi

# Test 3: Python Runtime on ARM
log "Test 3: Testing Python runtime on ARM..."
PYTHON_VERSION=$(docker run --rm --platform linux/arm/v6 --entrypoint python rew-pi-receiver:latest --version 2>/dev/null)
if echo "$PYTHON_VERSION" | grep -q "Python 3.11"; then
    success "Python runtime: $PYTHON_VERSION"
else
    error "Python runtime test failed: $PYTHON_VERSION"
    exit 1
fi

# Test 4: Architecture Validation
log "Test 4: Testing ARM architecture validation..."
ARCH_TEST=$(./test-arm-docker.sh 2>/dev/null | grep "Architecture:" | head -1)
if echo "$ARCH_TEST" | grep -q "armv7l\|armv6l"; then
    success "Architecture validated: $(echo $ARCH_TEST | sed 's/Architecture: //')"
else
    error "Architecture validation failed"
    exit 1
fi

# Test 5: Service Endpoint Testing
log "Test 5: Testing service endpoints..."
# Start container in background
CONTAINER_ID=$(docker run -d --platform linux/arm/v6 -p 8080:8080 -p 5004:5004/udp --name validation-test rew-pi-receiver:latest --device null --rtp-port 5004 --http-port 8080 2>/dev/null)

# Wait for startup
sleep 8

# Test HTTP status endpoint
if curl -s http://localhost:8080/status | grep -q '"status": "running"'; then
    success "HTTP status endpoint working"
else
    error "HTTP status endpoint failed"
    docker stop validation-test > /dev/null 2>&1 || true
    docker rm validation-test > /dev/null 2>&1 || true
    exit 1
fi

# Test health endpoint
if curl -s http://localhost:8080/health | grep -q '"status": "healthy"'; then
    success "Health endpoint working"
else
    error "Health endpoint failed"
    docker stop validation-test > /dev/null 2>&1 || true
    docker rm validation-test > /dev/null 2>&1 || true
    exit 1
fi

# Clean up test container
docker stop validation-test > /dev/null 2>&1 || true
docker rm validation-test > /dev/null 2>&1 || true

# Test 6: Build Artifacts
log "Test 6: Testing deployment build artifacts..."
if ls export/rew-pi-receiver-*.tar >/dev/null 2>&1 && [ -f "export/docker-compose.yaml" ]; then
    TAR_SIZE=$(ls -lh export/rew-pi-receiver-*.tar | awk '{print $5}')
    success "Deployment artifacts found (Docker image: $TAR_SIZE)"
else
    warning "No existing deployment artifacts, building..."
    if ./deploy-to-pi.sh build > /dev/null 2>&1; then
        if [ -f "export/rew-pi-receiver-*.tar" ] && [ -f "export/docker-compose.yaml" ]; then
            TAR_SIZE=$(ls -lh export/rew-pi-receiver-*.tar | awk '{print $5}')
            success "Deployment artifacts created (Docker image: $TAR_SIZE)"
        else
            error "Missing deployment artifacts"
            exit 1
        fi
    else
        error "Deployment build failed"
        exit 1
    fi
fi

# Test 7: ARM Emulation Setup
log "Test 7: Testing ARM emulation setup..."
if [ -d "arm-emulation" ] && [ -f "arm-emulation/raspios-lite-armhf.img" ]; then
    IMG_SIZE=$(ls -lh arm-emulation/raspios-lite-armhf.img | awk '{print $5}')
    success "ARM emulation environment ready (Pi OS: $IMG_SIZE)"
else
    warning "ARM emulation environment not set up (run ./setup-arm-emulation.sh)"
fi

# Test 8: Documentation Validation
log "Test 8: Validating documentation commands..."
if ./test-arm-docker.sh 2>/dev/null | grep -E "(armv7l|Python 3.11|running|healthy)" > /dev/null; then
    success "Documentation validation commands work"
else
    error "Documentation validation failed"
    exit 1
fi

echo ""
echo "🎉 All ARM Development Environment Tests Passed!"
echo ""
echo "✅ ARM container builds successfully"
echo "✅ Python 3.11 runtime works on ARM"
echo "✅ Service endpoints respond correctly"
echo "✅ Deployment artifacts generated"
echo "✅ Documentation commands validated"
echo ""
echo "🚀 Your ARM development environment is ready!"
echo "📖 See ARM-DEVELOPMENT.md for usage instructions"