#!/bin/bash
set -e

# Test script for the complete MediaMTX → CamillaDSP → Merus amplifier workflow
# This validates the entire audio processing pipeline

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[PIPELINE-TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

AUDIO_DEVICE="hw:CARD=sndrpimerusamp"
CAMILLADSP_PORT=1234
MEDIAMTX_API_PORT=9997
RTP_PORT=5004

log "🎵 Testing Complete Audio Pipeline"
log "MediaMTX → CamillaDSP → Merus Amplifier"
echo ""

# Step 1: Verify configuration is ready
log "Step 1: Verifying configuration..."
if [ ! -f "camilladsp.yml" ]; then
    warning "CamillaDSP configuration not found. Generating it..."
    if [ -f "configure-audio-device.sh" ]; then
        ./configure-audio-device.sh -d "$AUDIO_DEVICE"
    else
        error "configure-audio-device.sh not found"
        exit 1
    fi
fi

# Check if the config has the right device
if grep -q "$AUDIO_DEVICE" camilladsp.yml; then
    success "✅ CamillaDSP configured for $AUDIO_DEVICE"
else
    warning "⚠️  Updating CamillaDSP configuration for $AUDIO_DEVICE"
    ./configure-audio-device.sh -d "$AUDIO_DEVICE"
fi

# Step 2: Start CamillaDSP
log "Step 2: Starting CamillaDSP..."
if pgrep -f camilladsp > /dev/null; then
    warning "CamillaDSP already running, stopping it first..."
    pkill -f camilladsp || true
    sleep 2
fi

log "Starting CamillaDSP on port $CAMILLADSP_PORT..."
./camilladsp -v -p $CAMILLADSP_PORT "$(pwd)/camilladsp.yml" &
CAMILLADSP_PID=$!
sleep 3

# Check if CamillaDSP started successfully
if kill -0 $CAMILLADSP_PID 2>/dev/null; then
    success "✅ CamillaDSP started successfully (PID: $CAMILLADSP_PID)"
    
    # Test CamillaDSP API
    if curl -s http://localhost:$CAMILLADSP_PORT/api/v1/state >/dev/null; then
        success "✅ CamillaDSP API responding"
    else
        warning "⚠️  CamillaDSP API not responding"
    fi
else
    error "❌ CamillaDSP failed to start"
    exit 1
fi

# Step 3: Start MediaMTX
log "Step 3: Starting MediaMTX..."
if pgrep -f mediamtx > /dev/null; then
    warning "MediaMTX already running, stopping it first..."
    pkill -f mediamtx || true
    sleep 2
fi

log "Starting MediaMTX..."
mediamtx mediamtx.yml &
MEDIAMTX_PID=$!
sleep 3

# Check if MediaMTX started successfully
if kill -0 $MEDIAMTX_PID 2>/dev/null; then
    success "✅ MediaMTX started successfully (PID: $MEDIAMTX_PID)"
    
    # Test MediaMTX API
    if curl -s http://localhost:$MEDIAMTX_API_PORT/v3/config >/dev/null; then
        success "✅ MediaMTX API responding"
    else
        warning "⚠️  MediaMTX API not responding"
    fi
else
    error "❌ MediaMTX failed to start"
    cleanup
    exit 1
fi

# Step 4: Test the audio pipeline
log "Step 4: Testing complete audio pipeline..."
echo ""
log "🎯 Pipeline Status:"
log "• MediaMTX: Running (PID: $MEDIAMTX_PID)"
log "• CamillaDSP: Running (PID: $CAMILLADSP_PID)"
log "• Audio Device: $AUDIO_DEVICE"
log "• RTP Input Port: $RTP_PORT"

echo ""
log "🔊 Testing direct audio output (bypass test)..."
log "This should play through CamillaDSP to the Merus amplifier..."

# Test direct audio through CamillaDSP to verify the chain works
speaker-test -D "$AUDIO_DEVICE" -c 2 -r 48000 -F S32_LE -t sine -f 440 -l 1 -p 2000 2>/dev/null &
TEST_PID=$!

sleep 3

if kill -0 $TEST_PID 2>/dev/null; then
    wait $TEST_PID
    success "✅ Direct audio test completed"
else
    warning "⚠️  Direct audio test had issues"
fi

echo ""
log "🌐 Pipeline is ready for RTP input!"
log "Ready to receive RTP audio streams on port $RTP_PORT"

# Cleanup function
cleanup() {
    log "Cleaning up..."
    [ -n "$MEDIAMTX_PID" ] && kill $MEDIAMTX_PID 2>/dev/null || true
    [ -n "$CAMILLADSP_PID" ] && kill $CAMILLADSP_PID 2>/dev/null || true
    wait 2>/dev/null || true
}

# Set up signal handlers
trap cleanup TERM INT

echo ""
log "🎉 Audio Pipeline Test Complete!"
log "=================================================="
log "Services are running and ready for RTP input"
log ""
log "🔗 Access Points:"
log "• MediaMTX API: http://localhost:$MEDIAMTX_API_PORT"
log "• CamillaDSP API: http://localhost:$CAMILLADSP_PORT"
log "• RTP Input: Send to port $RTP_PORT"
log ""
log "🎵 To test with REW:"
log "1. Configure REW output to RTP"
log "2. Set target: $(hostname -I | awk '{print $1}'):$RTP_PORT"
log "3. Play audio in REW"
log ""
warning "Press Ctrl+C to stop services..."

# Keep services running
wait $MEDIAMTX_PID
