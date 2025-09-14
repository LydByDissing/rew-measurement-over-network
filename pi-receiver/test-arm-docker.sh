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

echo "🐳 ARM Container Testing with Docker Emulation"
echo "=============================================="

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

# First, build the ARM container if it doesn't exist
if ! docker images | grep -q "rew-pi-receiver.*latest"; then
    log "Building ARM container..."
    docker build --platform linux/arm/v6 -t rew-pi-receiver:latest .
fi

# Test 1: Architecture and Python compatibility
log "Step 1: Testing ARM architecture and Python compatibility..."

# Create a quick architecture test
cat > arch-test.sh << 'EOF'
#!/bin/bash
echo "🔍 Container Architecture Test"
echo "============================="
echo "Architecture: $(uname -m)"
echo "Python version: $(python --version)"
echo ""

echo "🐍 Testing critical Python modules..."
python -c "
try:
    import logging, time, socket, threading
    print('✅ All critical modules imported successfully')
    print(f'✅ Time module working: {time.time()}')
except Exception as e:
    print(f'❌ Module import failed: {e}')
    exit(1)
"
EOF

chmod +x arch-test.sh

docker run --rm --platform linux/arm/v6 \
    -v "$(pwd)/arch-test.sh:/arch-test.sh:ro" \
    --entrypoint /arch-test.sh \
    rew-pi-receiver:latest

success "Architecture test passed!"

# Test 2: Start the actual service and test connectivity  
log "Step 2: Starting REW Audio Receiver service..."
warning "This may be slower due to ARM emulation"

# Start the container in background with port mapping
log "Starting container with port forwarding..."
CONTAINER_ID=$(docker run -d --platform linux/arm/v6 \
    -p 8080:8080 \
    -p 5004:5004/udp \
    --name rew-arm-test \
    rew-pi-receiver:latest \
    --device null --rtp-port 5004 --http-port 8080 --verbose)

log "Container started with ID: ${CONTAINER_ID:0:12}"

# Wait for service to start
log "Waiting for service to initialize..."
sleep 8

# Test HTTP status endpoint
log "Testing HTTP status endpoint..."
for i in {1..10}; do
    if curl -s http://localhost:8080/status >/dev/null 2>&1; then
        success "HTTP endpoint is responding!"
        echo "📊 Status response:"
        curl -s http://localhost:8080/status | python -m json.tool 2>/dev/null || curl -s http://localhost:8080/status
        break
    else
        log "Attempt $i/10: Waiting for HTTP endpoint..."
        sleep 2
    fi
done

# Test health endpoint
log "Testing health endpoint..."
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    success "Health endpoint is responding!"
    echo "🏥 Health response:"
    curl -s http://localhost:8080/health | python -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    warning "Health endpoint not responding (may not be implemented)"
fi

# Test RTP port accessibility
log "Testing RTP port accessibility..."
if nc -u -z localhost 5004 2>/dev/null; then
    success "RTP port 5004 is accessible!"
else
    warning "RTP port test inconclusive (UDP port checking limitations)"
fi

# Show container logs
log "Container logs (last 20 lines):"
docker logs --tail 20 rew-arm-test

# Check if container is still running
if docker ps | grep -q rew-arm-test; then
    success "Container is running successfully!"
else
    error "Container has stopped"
    docker logs rew-arm-test
fi

# Clean up
log "Cleaning up test container..."
docker stop rew-arm-test >/dev/null 2>&1 || true
docker rm rew-arm-test >/dev/null 2>&1 || true

success "ARM service testing complete!"

# Clean up test files
rm -f arch-test.sh

echo ""
echo "📋 Results:"
echo "• ARM emulation is working if you see 'armv6l' or 'armv7l' architecture"
echo "• Python imports should work without timestamp errors"
echo "• Audio and network errors are expected in this test environment"
echo ""
echo "🚀 Next step: Deploy the container to an actual Raspberry Pi to test full functionality"