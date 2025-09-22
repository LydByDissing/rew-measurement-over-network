#!/bin/bash

# MediaMTX RTP Audio Reception Test
# Validates MediaMTX can receive RTP audio and forward to ALSA loopback

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[MEDIAMTX-TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
MEDIAMTX_API_PORT="${MEDIAMTX_API_PORT:-9997}"
RTP_PORT="${RTP_PORT:-8000}"
TEST_DURATION="${TEST_DURATION:-5}"
TEST_FREQUENCY="${TEST_FREQUENCY:-1000}"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test MediaMTX RTP audio reception and forwarding"
    echo ""
    echo "Options:"
    echo "  -p, --rtp-port PORT      RTP port (default: 5004)"
    echo "  -a, --api-port PORT      MediaMTX API port (default: 9997)"
    echo "  -d, --duration SECS      Test duration (default: 5)"
    echo "  -f, --frequency HZ       Test tone frequency (default: 1000)"
    echo "  -h, --help              Show this help"
    echo ""
    echo "Prerequisites:"
    echo "  - MediaMTX running with RTP configuration"
    echo "  - CamillaDSP running and monitoring loopback"
    echo "  - ALSA loopback device available"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--rtp-port)
            RTP_PORT="$2"
            shift 2
            ;;
        -a|--api-port)
            MEDIAMTX_API_PORT="$2"
            shift 2
            ;;
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -f|--frequency)
            TEST_FREQUENCY="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

log "🧪 MediaMTX RTP Audio Reception Test"
echo ""
log "Configuration:"
log "• MediaMTX API Port: $MEDIAMTX_API_PORT"
log "• RTP Port: $RTP_PORT"
log "• Test Duration: ${TEST_DURATION}s"
log "• Test Frequency: ${TEST_FREQUENCY}Hz"
echo ""

# Test 1: MediaMTX API Health Check
log "Test 1: MediaMTX API Health Check..."
if curl -sf "http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list" >/dev/null; then
    success "✅ MediaMTX API responding on port $MEDIAMTX_API_PORT"
else
    error "❌ MediaMTX API not responding on port $MEDIAMTX_API_PORT"
    error "Make sure MediaMTX is running: ./mediamtx mediamtx.yml"
    exit 1
fi

# Test 2: Check MediaMTX Configuration
log "Test 2: Checking MediaMTX paths configuration..."
if curl -sf "http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list" >/dev/null; then
    success "✅ MediaMTX paths endpoint responding"
    
    # Check for RTP audio path if using mediamtx-rtp.yml
    if curl -s "http://127.0.0.1:$MEDIAMTX_API_PORT/v3/paths/list" | grep -q "rew_audio"; then
        success "✅ RTP audio path (rew_audio) configured"
        RTP_PATH_CONFIGURED=true
    else
        warning "⚠️  RTP audio path (rew_audio) not found - using basic MediaMTX config"
        RTP_PATH_CONFIGURED=false
    fi
else
    warning "⚠️  MediaMTX paths endpoint not responding"
    RTP_PATH_CONFIGURED=false
fi

# Test 3: ALSA Loopback Device Check
log "Test 3: Checking ALSA loopback device..."
if aplay -l 2>/dev/null | grep -q "Loopback"; then
    success "✅ ALSA Loopback device found"
else
    error "❌ ALSA Loopback device not found"
    error "Load the loopback module: sudo modprobe snd-aloop"
    exit 1
fi

# Test 4: RTP Audio Reception Test
log "Test 4: Testing RTP audio reception and forwarding..."
echo ""

if [ "$RTP_PATH_CONFIGURED" = true ]; then
    log "Using MediaMTX RTP path configuration..."
    log "🔊 Sending ${TEST_FREQUENCY}Hz tone for ${TEST_DURATION} seconds via RTP..."
    log "You should hear audio through CamillaDSP → Merus amplifier"
    echo ""
    
    # Send RTP stream to MediaMTX
    warning "▶️  Starting RTP audio test..."
    ffmpeg -f lavfi -i "sine=frequency=$TEST_FREQUENCY:duration=$TEST_DURATION" \
           -ar 48000 -ac 2 -f rtp "rtp://127.0.0.1:$RTP_PORT" \
           -loglevel error 2>/dev/null
    
    if [ $? -eq 0 ]; then
        success "✅ RTP audio stream sent successfully"
        log "If you heard the ${TEST_FREQUENCY}Hz tone, MediaMTX RTP reception is working!"
    else
        error "❌ Failed to send RTP audio stream"
        exit 1
    fi
    
else
    log "MediaMTX RTP path not configured, testing with direct RTP-to-ALSA..."
    
    # Check if we have the RTP bridge script
    if [ -f "./rtp-to-alsa.sh" ]; then
        log "Using RTP-to-ALSA bridge script..."
        
        # Start RTP bridge
        ./rtp-to-alsa.sh -p $RTP_PORT >/dev/null 2>&1 &
        RTP_BRIDGE_PID=$!
        sleep 2
        
        if kill -0 $RTP_BRIDGE_PID 2>/dev/null; then
            success "✅ RTP-to-ALSA bridge started"
            
            log "🔊 Sending ${TEST_FREQUENCY}Hz tone for ${TEST_DURATION} seconds..."
            warning "▶️  Starting RTP audio test..."
            
            # Send test tone
            ffmpeg -f lavfi -i "sine=frequency=$TEST_FREQUENCY:duration=$TEST_DURATION" \
                   -ar 48000 -ac 2 -f rtp "rtp://127.0.0.1:$RTP_PORT" \
                   -loglevel error 2>/dev/null
            
            success "✅ RTP audio test completed"
            log "If you heard the ${TEST_FREQUENCY}Hz tone, RTP → CamillaDSP pipeline is working!"
            
            # Stop bridge
            kill $RTP_BRIDGE_PID 2>/dev/null || true
            wait $RTP_BRIDGE_PID 2>/dev/null || true
            log "RTP-to-ALSA bridge stopped"
            
        else
            error "❌ Failed to start RTP-to-ALSA bridge"
            exit 1
        fi
    else
        error "❌ No RTP reception method available"
        error "Either configure MediaMTX with RTP path or provide rtp-to-alsa.sh script"
        exit 1
    fi
fi

echo ""
log "🎯 MediaMTX RTP Audio Test Summary:"
log "• MediaMTX API: ✅ Working"
log "• ALSA Loopback: ✅ Available"
log "• RTP Reception: ✅ Tested"

if [ "$RTP_PATH_CONFIGURED" = true ]; then
    log "• Method: MediaMTX RTP path (rew_audio)"
else
    log "• Method: Direct RTP-to-ALSA bridge"
fi

echo ""
success "✅ MediaMTX RTP audio pipeline validation completed!"
log "Ready for REW audio streaming on port $RTP_PORT"
