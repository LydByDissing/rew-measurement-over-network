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
RTP_PORT=8000

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
./camilladsp -p $CAMILLADSP_PORT "$(pwd)/camilladsp.yml" &
CAMILLADSP_PID=$!
sleep 3

# Check if CamillaDSP started successfully
if kill -0 $CAMILLADSP_PID 2>/dev/null; then
    success "✅ CamillaDSP started successfully (PID: $CAMILLADSP_PID)"
    
    # Test CamillaDSP API
    if curl -s http://127.0.0.1:$CAMILLADSP_PORT/api/v1/state >/dev/null; then
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
./mediamtx mediamtx.yml &
MEDIAMTX_PID=$!
sleep 3

# Check if MediaMTX started successfully
if kill -0 $MEDIAMTX_PID 2>/dev/null; then
    success "✅ MediaMTX started successfully (PID: $MEDIAMTX_PID)"
    
    # Test MediaMTX API
    if curl -s http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list >/dev/null; then
        success "✅ MediaMTX API responding"
        
        # Test MediaMTX paths endpoint
        log "Checking MediaMTX paths configuration..."
        if curl -s http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list >/dev/null; then
            success "✅ MediaMTX paths endpoint responding"
            
            # Check if rew_audio path is configured
            if curl -s http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list | grep -q "rew_audio"; then
                success "✅ RTP audio path (rew_audio) is configured"
            else
                warning "⚠️  RTP audio path (rew_audio) not found in configuration"
            fi
        else
            warning "⚠️  MediaMTX paths endpoint not responding"
        fi
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
log "🔊 Testing CamillaDSP pipeline (loopback test)..."
log "This should play through CamillaDSP to the Merus amplifier..."

# Test audio through the loopback device that CamillaDSP is monitoring
# This properly tests the CamillaDSP pipeline without device conflicts
speaker-test -D "plughw:CARD=Loopback,DEV=0" -c 2 -r 48000 -F S16LE -t sine -f 440 -l 1 -p 2000 2>/dev/null &
TEST_PID=$!

sleep 3

if kill -0 $TEST_PID 2>/dev/null; then
    wait $TEST_PID
    success "✅ CamillaDSP pipeline test completed"
else
    warning "⚠️  CamillaDSP pipeline test had issues"
fi

echo ""
log "🎵 Testing RTP audio reception and forwarding..."

# Test RTP audio pipeline using our RTP bridge or MediaMTX
if [ -f "./rtp-to-alsa.sh" ]; then
    log "Testing RTP-to-ALSA bridge..."
    
    # Start RTP bridge in background
    ./rtp-to-alsa.sh -p $RTP_PORT >/dev/null 2>&1 &
    RTP_BRIDGE_PID=$!
    sleep 2
    
    if kill -0 $RTP_BRIDGE_PID 2>/dev/null; then
        success "✅ RTP-to-ALSA bridge started (PID: $RTP_BRIDGE_PID)"
        
        # Test RTP audio stream
        log "Sending test RTP audio stream..."
        log "🔊 You should hear a 1000Hz tone for 5 seconds through the Merus amplifier..."
        
        # Generate test RTP stream
        timeout 5 ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" \
                         -ar 48000 -ac 2 -f rtp "rtp://127.0.0.1:$RTP_PORT" \
                         -loglevel error >/dev/null 2>&1 &
        RTP_TEST_PID=$!
        
        # Wait for test to complete
        wait $RTP_TEST_PID
        RTP_EXIT_CODE=$?
        
        if [ $RTP_EXIT_CODE -eq 0 ] || [ $RTP_EXIT_CODE -eq 124 ]; then  # 124 = timeout success
            success "✅ RTP audio test stream completed"
            log "If you heard the tone, the complete RTP → CamillaDSP → Merus pipeline is working!"
        else
            warning "⚠️  RTP audio test stream failed (exit code: $RTP_EXIT_CODE)"
        fi
        
        # Stop RTP bridge
        kill $RTP_BRIDGE_PID 2>/dev/null || true
        wait $RTP_BRIDGE_PID 2>/dev/null || true
        log "RTP-to-ALSA bridge stopped"
        
    else
        warning "⚠️  Failed to start RTP-to-ALSA bridge"
    fi
else
    log "RTP-to-ALSA bridge script not found, testing with direct ffmpeg..."
    
    # Direct test without bridge
    log "Testing direct RTP reception..."
    log "🔊 You should hear a 1000Hz tone for 3 seconds through the Merus amplifier..."
    
    # Start direct RTP-to-ALSA forwarding in background
    timeout 10 ffmpeg -f rtp -i rtp://127.0.0.1:$RTP_PORT \
                      -f alsa -acodec pcm_s16le -ac 2 -ar 48000 plughw:CARD=Loopback,DEV=0 \
                      -loglevel error >/dev/null 2>&1 &
    RTP_RECEIVER_PID=$!
    
    sleep 1
    
    # Send test stream
    timeout 3 ffmpeg -f lavfi -i "sine=frequency=1000:duration=3" \
                     -ar 48000 -ac 2 -f rtp "rtp://127.0.0.1:$RTP_PORT" \
                     -loglevel error >/dev/null 2>&1
    
    success "✅ Direct RTP test completed"
    
    # Clean up
    kill $RTP_RECEIVER_PID 2>/dev/null || true
    wait $RTP_RECEIVER_PID 2>/dev/null || true
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
log "• MediaMTX API: http://127.0.0.1:$MEDIAMTX_API_PORT"
log "• CamillaDSP API: http://127.0.0.1:$CAMILLADSP_PORT"
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
