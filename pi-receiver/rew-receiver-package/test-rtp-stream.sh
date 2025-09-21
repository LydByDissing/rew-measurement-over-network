#!/bin/bash

# Test RTP streaming to the MediaMTX → CamillaDSP → Merus amplifier pipeline
# This script generates a test RTP stream to validate the complete workflow

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[RTP-TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

RTP_PORT=5004
TARGET_IP="${1:-127.0.0.1}"
TEST_DURATION="${2:-10}"

show_usage() {
    echo "Usage: $0 [TARGET_IP] [DURATION]"
    echo ""
    echo "Test RTP streaming to MediaMTX pipeline"
    echo ""
    echo "Parameters:"
    echo "  TARGET_IP    IP address of MediaMTX receiver (default: 127.0.0.1)"
    echo "  DURATION     Test duration in seconds (default: 10)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test locally for 10 seconds"
    echo "  $0 192.168.1.100            # Test to remote Pi for 10 seconds"
    echo "  $0 192.168.1.100 30         # Test to remote Pi for 30 seconds"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

log "🎵 Testing RTP Stream to MediaMTX Pipeline"
log "Target: $TARGET_IP:$RTP_PORT"
log "Duration: ${TEST_DURATION}s"
echo ""

# Check if ffmpeg is available
if ! command -v ffmpeg >/dev/null 2>&1; then
    error "ffmpeg not found. Please install ffmpeg to generate test RTP streams."
    exit 1
fi

# Check if pipeline services are running (if testing locally)
if [ "$TARGET_IP" = "127.0.0.1" ] || [ "$TARGET_IP" = "localhost" ]; then
    log "Checking local services..."
    
    if ! pgrep -f mediamtx >/dev/null; then
        warning "MediaMTX not running locally. Start it first:"
        warning "  ./test-full-pipeline.sh"
        exit 1
    fi
    
    if ! pgrep -f camilladsp >/dev/null; then
        warning "CamillaDSP not running locally. Start it first:"
        warning "  ./test-full-pipeline.sh"
        exit 1
    fi
    
    success "✅ Local services are running"
fi

# Test network connectivity
log "Testing network connectivity to $TARGET_IP:$RTP_PORT..."
if timeout 3 bash -c "echo >/dev/udp/$TARGET_IP/$RTP_PORT" 2>/dev/null; then
    success "✅ Network connectivity OK"
else
    warning "⚠️  Cannot test UDP connectivity (this might be normal)"
fi

echo ""
log "🎵 Generating test RTP stream..."
log "You should hear a 1000Hz tone through the Merus amplifier"
log "Duration: ${TEST_DURATION} seconds"

# Generate a test tone and stream it via RTP
echo ""
warning "▶️  Starting RTP stream..."

ffmpeg -f lavfi -i "sine=frequency=1000:duration=$TEST_DURATION" \
       -ar 48000 -ac 2 -f rtp "rtp://$TARGET_IP:$RTP_PORT" \
       -loglevel error 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    success "✅ RTP stream completed successfully!"
    echo ""
    log "If you heard a 1000Hz tone, the complete pipeline is working:"
    log "RTP Stream → MediaMTX → CamillaDSP → Merus Amplifier"
else
    echo ""
    error "❌ RTP stream failed"
    echo ""
    log "Troubleshooting steps:"
    log "1. Ensure MediaMTX is running: pgrep -f mediamtx"
    log "2. Ensure CamillaDSP is running: pgrep -f camilladsp"
    log "3. Check network connectivity to $TARGET_IP"
    log "4. Verify port $RTP_PORT is not blocked"
fi

echo ""
log "💡 To test with REW:"
log "1. Configure REW: Generator → RTA → Output Device: Network/RTP"
log "2. Set RTP target: $TARGET_IP:$RTP_PORT"
log "3. Start REW measurement/generator"
