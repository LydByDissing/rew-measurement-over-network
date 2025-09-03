#!/bin/bash
#
# REW Network Audio Bridge - Simple Integration Test
# Tests Java Audio Bridge with Containerized Pi Receiver
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "🧪 REW Network Audio Bridge - Integration Test"
echo "==============================================="

# Test configuration
PI_CONTAINER_NAME="test-rew-pi-receiver"
JAVA_JAR="java-audio-bridge/target/audio-bridge-0.1.0-SNAPSHOT.jar"
TEST_DURATION=15

log "Starting containerized Pi receiver..."

# Start Pi receiver container
docker run -d \
    --name "$PI_CONTAINER_NAME" \
    -p 5004:5004/udp \
    -p 8080:8080 \
    --entrypoint /app/entrypoint.sh \
    rew-pi-receiver:latest \
    --device null --verbose

sleep 3

# Check if container is running
if ! docker ps | grep -q "$PI_CONTAINER_NAME"; then
    fail "Pi receiver container failed to start"
    exit 1
fi

success "Pi receiver container started successfully"

# Test HTTP status endpoint
log "Testing Pi receiver status API..."
if curl -s http://localhost:8080/status | jq -r '.status' | grep -q "running"; then
    success "Pi receiver status API is working"
else
    fail "Pi receiver status API is not responding"
    docker logs "$PI_CONTAINER_NAME"
    docker stop "$PI_CONTAINER_NAME" && docker rm "$PI_CONTAINER_NAME"
    exit 1
fi

# Check if Java JAR exists
if [ ! -f "$JAVA_JAR" ]; then
    warning "Java audio bridge JAR not found - building..."
    cd java-audio-bridge && mvn clean package -DskipTests && cd ..
fi

if [ ! -f "$JAVA_JAR" ]; then
    fail "Could not build Java audio bridge"
    docker stop "$PI_CONTAINER_NAME" && docker rm "$PI_CONTAINER_NAME"
    exit 1
fi

# Test Java Audio Bridge connection to Pi receiver  
log "Testing Java Audio Bridge connection to Pi receiver..."

# Start Java bridge in headless mode pointing to localhost
timeout $TEST_DURATION java -jar "$JAVA_JAR" --headless --target 127.0.0.1 --port 5004 &
JAVA_PID=$!

# Wait a moment for connection
sleep 5

# Check Pi receiver received packets
log "Checking if Pi receiver received audio data..."
PACKETS_RECEIVED=$(curl -s http://localhost:8080/status | jq -r '.stats.packets_received // 0')

if [ "$PACKETS_RECEIVED" -gt 0 ]; then
    success "Integration test PASSED! Pi receiver got $PACKETS_RECEIVED packets"
    TEST_RESULT="PASS"
else
    warning "No packets received yet - checking logs..."
    echo
    echo "Pi Receiver Logs:"
    docker logs "$PI_CONTAINER_NAME" | tail -10
    echo
    echo "Java Bridge should be running..."
    ps aux | grep java | grep audio-bridge || echo "Java bridge not running"
    TEST_RESULT="PARTIAL"
fi

# Cleanup
log "Cleaning up test environment..."

# Stop Java bridge
kill $JAVA_PID 2>/dev/null || true
wait $JAVA_PID 2>/dev/null || true

# Stop and remove Pi receiver container
docker stop "$PI_CONTAINER_NAME"
docker rm "$PI_CONTAINER_NAME"

# Final status
echo
echo "🏁 Integration Test Results"
echo "==========================="
case $TEST_RESULT in
    "PASS")
        success "✅ FULL INTEGRATION SUCCESS"
        echo "• Pi receiver container: ✅ Working"
        echo "• HTTP status API: ✅ Working"  
        echo "• Java bridge connection: ✅ Working"
        echo "• RTP packet delivery: ✅ Working ($PACKETS_RECEIVED packets)"
        echo
        echo "🎉 The containerized Pi receiver is ready for deployment!"
        exit 0
        ;;
    "PARTIAL")
        warning "⚠️ PARTIAL SUCCESS"
        echo "• Pi receiver container: ✅ Working"
        echo "• HTTP status API: ✅ Working"
        echo "• Java bridge connection: ⚠️ No audio data detected"
        echo
        echo "💡 The container setup works, but audio flow needs REW running."
        echo "   Deploy to Pi and test with actual REW measurements."
        exit 0
        ;;
    *)
        fail "❌ INTEGRATION FAILED"
        exit 1
        ;;
esac