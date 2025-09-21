#!/bin/bash

# Debug script to test CamillaDSP startup and identify issues

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEBUG]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🔧 CamillaDSP Debug Script"
echo ""

# Check for CamillaDSP binary
log "Checking CamillaDSP binary..."
if [ -f "./camilladsp" ]; then
    success "✅ Local CamillaDSP binary found"
    ls -la ./camilladsp
    
    # Check binary architecture
    file ./camilladsp
    
    # Try to get version/help
    log "Testing binary execution..."
    if ./camilladsp --version 2>&1 | head -3; then
        success "✅ Binary executes successfully"
    else
        warning "⚠️  Binary version check failed"
        ./camilladsp --help 2>&1 | head -10
    fi
else
    error "❌ Local CamillaDSP binary not found"
    if command -v camilladsp >/dev/null 2>&1; then
        log "System CamillaDSP found at: $(which camilladsp)"
    else
        error "❌ No CamillaDSP binary available"
        exit 1
    fi
fi

echo ""

# Check configuration file
log "Checking configuration file..."
if [ -f "camilladsp.yml" ]; then
    success "✅ Configuration file found"
    log "Configuration file size: $(stat -c%s camilladsp.yml) bytes"
    log "Configuration file path: $(pwd)/camilladsp.yml"
    
    # Show first few lines of config
    log "Configuration preview:"
    head -10 camilladsp.yml | sed 's/^/    /'
else
    error "❌ Configuration file 'camilladsp.yml' not found"
    log "Available config files:"
    ls -la *.yml 2>/dev/null || echo "    No .yml files found"
    exit 1
fi

echo ""

# Test CamillaDSP startup
log "Testing CamillaDSP startup..."
PORT=1234

log "Command to test: ./camilladsp -v -p $PORT \"$(pwd)/camilladsp.yml\""
echo ""

log "Starting CamillaDSP (will run for 5 seconds)..."
./camilladsp -v -p $PORT "$(pwd)/camilladsp.yml" &
CAMILLADSP_PID=$!

sleep 2

# Check if process is running
if kill -0 $CAMILLADSP_PID 2>/dev/null; then
    success "✅ CamillaDSP started successfully (PID: $CAMILLADSP_PID)"
    
    # Test API endpoint
    log "Testing CamillaDSP API..."
    if curl -s http://localhost:$PORT/api/v1/state >/dev/null 2>&1; then
        success "✅ CamillaDSP API responding"
        curl -s http://localhost:$PORT/api/v1/state | head -5
    else
        warning "⚠️  CamillaDSP API not responding"
        log "Checking if port is in use:"
        netstat -tuln | grep :$PORT || echo "    Port $PORT not in use"
    fi
    
    # Stop the test process
    log "Stopping test CamillaDSP..."
    kill $CAMILLADSP_PID 2>/dev/null
    wait $CAMILLADSP_PID 2>/dev/null
    success "✅ Test completed"
else
    error "❌ CamillaDSP failed to start"
    log "Process may have exited with error. Check audio device configuration."
    log ""
    log "Common issues:"
    log "1. Audio device not available"
    log "2. Permission issues with audio system"
    log "3. Port $PORT already in use"
    log "4. Invalid configuration file"
fi

echo ""
log "Debug complete."
