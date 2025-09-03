#!/bin/bash

# Test script to validate Docker-based REW Network Audio Bridge testing
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[DOCKER-TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🐳 REW Network Audio Bridge - Docker Integration Test Setup"
echo "============================================================="

# Check prerequisites
log "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    fail "Docker is not installed or not in PATH"
fi

if ! docker compose version &> /dev/null; then
    if ! command -v docker-compose &> /dev/null; then
        fail "Docker Compose is not installed or not in PATH (tried 'docker compose' and 'docker-compose')"
    else
        warn "Using legacy docker-compose command"
        COMPOSE_CMD="docker-compose"
    fi
else
    COMPOSE_CMD="docker compose"
fi

if ! docker info &> /dev/null; then
    fail "Docker daemon is not running or not accessible"
fi

success "Docker prerequisites are satisfied"

# Clean up any existing containers
log "Cleaning up existing test containers..."
$COMPOSE_CMD -f docker-compose.test.yml down --volumes --remove-orphans 2>/dev/null || true
success "Cleanup completed"

# Build the images
log "Building Docker images..."
if $COMPOSE_CMD -f docker-compose.test.yml build; then
    success "Docker images built successfully"
else
    fail "Failed to build Docker images"
fi

# Create test audio directory
log "Setting up test environment..."
mkdir -p test-results
mkdir -p test-audio

# Generate simple test audio if sox is available
if command -v sox &> /dev/null; then
    log "Generating test audio files..."
    sox -n -t wav test-audio/test-tone.wav synth 2 sine 440 vol 0.5 2>/dev/null || true
fi

success "Test environment setup completed"

# Start the test environment
log "Starting Docker test environment..."
if $COMPOSE_CMD -f docker-compose.test.yml up --abort-on-container-exit --exit-code-from test-runner; then
    success "Docker integration tests completed successfully"
    TEST_RESULT="PASSED"
else
    warn "Some Docker integration tests failed"
    TEST_RESULT="FAILED"
fi

# Show test results
log "Displaying test results..."
if [ -f test-results/test-summary.json ]; then
    echo "Test Summary:"
    cat test-results/test-summary.json | jq -r '"Tests Passed: " + (.tests_passed | tostring) + ", Tests Failed: " + (.tests_failed | tostring)' 2>/dev/null || cat test-results/test-summary.json
else
    warn "No test results file found"
fi

# Cleanup
log "Cleaning up test environment..."
$COMPOSE_CMD -f docker-compose.test.yml down --volumes 2>/dev/null || true

echo
echo "==============================================="
echo "Docker Integration Test Summary"  
echo "==============================================="
echo -e "Overall Result: ${GREEN}$TEST_RESULT${NC}"
echo
echo "This test validates:"
echo "✓ Docker container networking (192.168.100.0/24)"
echo "✓ Java Audio Bridge containerization"
echo "✓ Pi Receiver simulation"  
echo "✓ RTP streaming protocol"
echo "✓ Service discovery simulation"
echo "✓ End-to-end system integration"
echo
echo "Next Steps:"
echo "1. Run actual REW software tests"
echo "2. Test with real Pi hardware"
echo "3. Validate audio quality and latency"
echo "==============================================="

if [ "$TEST_RESULT" = "PASSED" ]; then
    exit 0
else
    exit 1
fi