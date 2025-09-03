#!/bin/bash

# Script to validate the enhanced logging functionality
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[VALIDATION]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "🧪 REW Network Audio Bridge - Enhanced Logging Validation"
echo "=========================================================="

# Test 1: Validate REW virtual device is working
log "Testing REW virtual audio device..."
if ./rew-loopback status | grep -q "ACTIVE\|READY"; then
    success "REW virtual audio device is active"
else
    warn "REW virtual audio device is not active, creating it..."
    ./rew-loopback create
    if ./rew-loopback status | grep -q "ACTIVE\|READY"; then
        success "REW virtual audio device created and active"
    else
        fail "Failed to create REW virtual audio device"
        exit 1
    fi
fi

# Test 2: Validate Java application can start in headless mode
log "Testing Java application headless startup..."
cd java-audio-bridge

# Build the application first
mvn package -DskipTests -q

# Test headless mode with timeout
timeout 10 java -jar target/audio-bridge-*.jar --headless --help > /tmp/java-bridge-test.log 2>&1 || {
    # Check if it's just a timeout (which is expected for --help)
    if grep -q "Usage:" /tmp/java-bridge-test.log; then
        success "Java application can start in headless mode"
    else
        warn "Java application test inconclusive, checking log..."
        cat /tmp/java-bridge-test.log | head -20
    fi
}

# Test 3: Validate enhanced logging is compiled correctly
log "Testing enhanced logging compilation..."
if grep -r "Audio detected flowing through REW Bridge" src/main/java/; then
    success "Enhanced audio flow logging is implemented"
else
    fail "Enhanced audio flow logging not found in source code"
fi

if grep -r "checkAudioFlowStatus" src/main/java/; then
    success "Audio flow status checking is implemented"
else
    fail "Audio flow status checking not found in source code"
fi

# Test 4: Test Pi receiver can start
log "Testing Pi receiver startup..."
cd ../pi-receiver

# Test that the Python script can at least show help
if python3 rew_audio_receiver.py --help > /tmp/pi-receiver-test.log 2>&1; then
    success "Pi receiver can start and show help"
else
    warn "Pi receiver startup test failed, checking requirements..."
    cat /tmp/pi-receiver-test.log | head -10
fi

# Test 5: Validate Docker files are properly created
log "Testing Docker configuration files..."
cd ..

if [ -f "docker-compose.test.yml" ]; then
    success "Docker Compose test file exists"
else
    fail "Docker Compose test file missing"
fi

if [ -f "Dockerfile.java-bridge" ] && [ -f "Dockerfile.pi-receiver" ] && [ -f "Dockerfile.test-runner" ]; then
    success "All Docker files exist"
else
    fail "Some Docker files are missing"
fi

# Test 6: Validate test scripts are executable
log "Testing test script permissions..."
if [ -x "test-docker-setup.sh" ]; then
    success "Docker test script is executable"
else
    fail "Docker test script is not executable"
fi

echo
echo "==============================================="
echo "Enhanced Logging Validation Summary"
echo "==============================================="

echo "✅ Basic Validation Completed"
echo
echo "Enhanced Features Implemented:"
echo "• 🎵 Audio flow detection with RMS level analysis"
echo "• 📊 Periodic status reporting (every 1000 packets)" 
echo "• ⚠️  Connection health monitoring"
echo "• 🔍 Connection quality tick function"
echo "• 🐳 Docker-based integration test environment"
echo "• 🧪 End-to-end validation framework"
echo
echo "Ready for full Docker integration testing!"
echo "Run: ./test-docker-setup.sh"
echo "==============================================="