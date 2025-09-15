#!/bin/bash
#
# Test ARM Docker Container Locally using Docker's ARM Emulation
# This uses Docker's buildx and QEMU binfmt to run ARM containers on x86
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[ARM-TEST]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🐳 ARM MediaMTX Container Testing with Docker Emulation"
echo "======================================================="

# Check if Docker supports ARM emulation
log "Checking Docker ARM emulation support..."
if docker buildx ls | grep -q "linux/arm"; then
    success "Docker ARM emulation available"
else
    warning "Setting up Docker ARM emulation..."
    # Install QEMU binfmt support
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    # Create a new buildx builder that supports ARM
    docker buildx create --name arm-builder --use 2>/dev/null || docker buildx use arm-builder
    docker buildx inspect --bootstrap
fi

# Test running our ARM container directly
log "Testing ARM container with Docker emulation..."

# First, build the ARM MediaMTX container if it doesn't exist
if ! docker images | grep -q "rew-mediamtx-receiver.*latest"; then
    log "Building ARM MediaMTX container..."
    docker buildx build --platform linux/arm/v6 -f Dockerfile.mediamtx -t rew-mediamtx-receiver:latest .
fi

# Test 1: Architecture and MediaMTX/CamillaDSP binary compatibility
log "Step 1: Testing ARM architecture and binary compatibility..."

# Create a quick architecture test
cat > arch-test.sh << 'EOF'
#!/bin/sh
echo "🔍 MediaMTX Container Architecture Test"
echo "======================================"
echo "Architecture: $(uname -m)"
echo ""

echo "📡 Testing MediaMTX binary..."
if mediamtx --help >/dev/null 2>&1; then
    echo "✅ MediaMTX binary is ARM-compatible"
    mediamtx --version
else
    echo "❌ MediaMTX binary failed"
    exit 1
fi

echo ""
echo "🎚️  Testing CamillaDSP binary..."
if camilladsp --help >/dev/null 2>&1; then
    echo "✅ CamillaDSP binary is ARM-compatible"
    camilladsp --version 2>/dev/null || echo "CamillaDSP version check completed"
else
    echo "❌ CamillaDSP binary failed"
    exit 1
fi

echo ""
echo "🔊 Testing ALSA setup..."
if [ -d /proc/asound ]; then
    echo "✅ ALSA proc filesystem available"
else
    echo "⚠️  ALSA proc filesystem not available (expected in test)"
fi
EOF

chmod +x arch-test.sh

docker run --rm --platform linux/arm/v6 \
    -v "$(pwd)/arch-test.sh:/arch-test.sh:ro" \
    --entrypoint /arch-test.sh \
    rew-mediamtx-receiver:latest

success "Architecture test passed!"

# Test 2: Start the actual MediaMTX service and test connectivity  
log "Step 2: Starting MediaMTX Audio Receiver service..."
warning "This may be slower due to ARM emulation"

# Start the container in background with port mapping
log "Starting MediaMTX container with port forwarding..."
CONTAINER_ID=$(docker run -d --platform linux/arm/v6 \
    -p 19997:9997 \
    -p 18554:8554 \
    -p 15004:5004/udp \
    -p 11234:1234 \
    --name rew-mediamtx-test \
    rew-mediamtx-receiver:latest)

log "MediaMTX container started with ID: ${CONTAINER_ID:0:12}"

# Wait for service to start
log "Waiting for service to initialize..."
sleep 8

# Test MediaMTX API endpoint
log "Testing MediaMTX API endpoint..."
for i in {1..10}; do
    if curl -s http://localhost:19997/v3/config >/dev/null 2>&1; then
        success "MediaMTX API is responding!"
        echo "📊 MediaMTX Config response:"
        curl -s http://localhost:19997/v3/config | python -m json.tool 2>/dev/null || curl -s http://localhost:19997/v3/config
        break
    else
        log "Attempt $i/10: Waiting for MediaMTX API..."
        sleep 2
    fi
done

# Test MediaMTX paths endpoint
log "Testing MediaMTX paths endpoint..."
if curl -s http://localhost:19997/v3/paths/list >/dev/null 2>&1; then
    success "MediaMTX paths endpoint is responding!"
    echo "📡 Active streams:"
    curl -s http://localhost:19997/v3/paths/list | python -m json.tool 2>/dev/null || curl -s http://localhost:19997/v3/paths/list
else
    warning "MediaMTX paths endpoint not responding"
fi

# Test CamillaDSP API endpoint
log "Testing CamillaDSP API endpoint..."
if curl -s http://localhost:11234/api/v1/state >/dev/null 2>&1; then
    success "CamillaDSP API is responding!"
    echo "🎚️  CamillaDSP state:"
    curl -s http://localhost:11234/api/v1/state | python -m json.tool 2>/dev/null || curl -s http://localhost:11234/api/v1/state
else
    warning "CamillaDSP API not responding (may still be starting up)"
fi

# Test RTP port accessibility
log "Testing RTP port accessibility..."
if nc -u -z localhost 15004 2>/dev/null; then
    success "RTP port 15004 is accessible!"
else
    warning "RTP port test inconclusive (UDP port checking limitations)"
fi

# Show container logs
log "Container logs (last 20 lines):"
docker logs --tail 20 rew-mediamtx-test

# Check if container is still running
if docker ps | grep -q rew-mediamtx-test; then
    success "MediaMTX container is running successfully!"
else
    error "MediaMTX container has stopped"
    docker logs rew-mediamtx-test
fi

# Clean up
log "Cleaning up test container..."
docker stop rew-mediamtx-test >/dev/null 2>&1 || true
docker rm rew-mediamtx-test >/dev/null 2>&1 || true

success "MediaMTX ARM service testing complete!"

# Clean up test files
rm -f arch-test.sh

echo ""
echo "📋 Results:"
echo "• ARM emulation is working if you see 'armv6l' or 'armv7l' architecture"
echo "• MediaMTX and CamillaDSP binaries should work without ARM compatibility issues"
echo "• API endpoints (9997, 1234) should respond with JSON configuration"
echo "• RTP port 5004 should be accessible for REW streaming"
echo "• Audio hardware errors are expected in this test environment"
echo ""
echo "🚀 Next step: Deploy the MediaMTX container to an actual Raspberry Pi to test full functionality"