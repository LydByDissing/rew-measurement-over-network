#!/bin/bash

# Ultra-Robust REW RTP Bridge - Handles packet loss and timing issues
# Uses buffering strategies optimized for finite duration measurements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[REW-ROBUST]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
RTP_PORT="${RTP_PORT:-5004}"
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=Loopback,DEV=0}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
CHANNELS="${CHANNELS:-2}"
RESTART_DELAY=1

# Cleanup function
cleanup() {
    log "Shutting down robust REW RTP bridge..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Function to run single FFmpeg instance with robust settings
run_robust_ffmpeg() {
    local instance_num=$1
    
    log "[$instance_num] Starting robust FFmpeg with anti-packet-loss settings..."
    
    # Ultra-robust FFmpeg command optimized for REW measurements
    # Removes real-time constraint and adds maximum buffering
    ffmpeg -hide_banner -loglevel error \
        -f rtp \
        -analyzeduration 200000 -probesize 131072 \
        -fflags +genpts+igndts+discardcorrupt \
        -avoid_negative_ts make_zero \
        -max_delay 2000000 \
        -buffer_size 8388608 \
        -i "rtp://0.0.0.0:$RTP_PORT?localport=$RTP_PORT&buffer_size=8388608" \
        -f alsa \
        -acodec pcm_s16le \
        -ac $CHANNELS \
        -ar $SAMPLE_RATE \
        -bufsize 4096k \
        -flush_packets 0 \
        -async 1 \
        "$ALSA_DEVICE" 2>&1 | while read line; do
            echo "[$instance_num] FFmpeg: $line"
        done
}

log "🎵 Starting Ultra-Robust REW RTP Bridge..."
log "RTP Port: $RTP_PORT"
log "ALSA Device: $ALSA_DEVICE"
log "Sample Rate: $SAMPLE_RATE Hz"
log "Channels: $CHANNELS"
echo ""

# Check if FFmpeg is available
if ! command -v ffmpeg >/dev/null 2>&1; then
    error "FFmpeg is not installed or not in PATH"
    exit 1
fi

# Increase system UDP buffer sizes for better packet handling
log "Optimizing system UDP buffers..."
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf >/dev/null || true
echo 'net.core.rmem_default = 262144' | sudo tee -a /etc/sysctl.conf >/dev/null || true
sudo sysctl -p >/dev/null 2>&1 || warning "Could not optimize UDP buffers (non-critical)"

log "🎯 Ultra-robust mode for REW measurements!"
log "Optimized for: packet loss tolerance, large buffers, finite duration streams"
log "Press Ctrl+C to stop"
echo ""

# Main loop - restart FFmpeg when it exits
instance=1
while true; do
    log "[$instance] Ready for REW measurement (ultra-robust mode)..."
    
    # Run FFmpeg - it will exit when RTP stream ends
    if run_robust_ffmpeg $instance; then
        success "[$instance] Measurement completed successfully"
    else
        exit_code=$?
        if [ $exit_code -eq 130 ]; then
            # Ctrl+C pressed
            log "Received interrupt signal"
            break
        fi
        log "[$instance] FFmpeg exited with code $exit_code (normal for finite streams)"
    fi
    
    log "[$instance] Waiting ${RESTART_DELAY}s before ready for next measurement..."
    sleep $RESTART_DELAY
    instance=$((instance + 1))
done

log "Ultra-Robust REW RTP Bridge stopped"
