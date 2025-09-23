#!/bin/bash

# REW-Specific RTP Bridge - Handles finite duration streams with auto-restart
# Perfect for REW measurements which send finite duration sweeps

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[REW-RTP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
RTP_PORT="${RTP_PORT:-5004}"
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=Loopback,DEV=0}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
CHANNELS="${CHANNELS:-2}"
RESTART_DELAY=2

# Cleanup function
cleanup() {
    log "Shutting down REW RTP bridge..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Function to run single FFmpeg instance
run_ffmpeg_instance() {
    local instance_num=$1
    
    SCRIPT_DIR="$(dirname "$0")"
    SDP_FILE="$SCRIPT_DIR/audio.sdp"

    if [ -f "$SDP_FILE" ]; then
        log "[$instance_num] Using SDP configuration for REW measurements"
        # Optimized for REW finite duration streams with better buffering
        ffmpeg -hide_banner -loglevel warning \
            -protocol_whitelist file,rtp,udp \
            -analyzeduration 500000 -probesize 65536 \
            -fflags +genpts+igndts -avoid_negative_ts make_zero \
            -max_delay 1000000 -buffer_size 4194304 \
            -i "$SDP_FILE" \
            -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE \
            -bufsize 2048k -flush_packets 1 \
            "$ALSA_DEVICE"
    else
        warning "[$instance_num] SDP file not found, using direct RTP"
        ffmpeg -hide_banner -loglevel warning \
            -f rtp -analyzeduration 500000 -probesize 65536 \
            -fflags +genpts+igndts -avoid_negative_ts make_zero \
            -max_delay 1000000 -buffer_size 4194304 \
            -i "rtp://0.0.0.0:$RTP_PORT" \
            -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE \
            -bufsize 2048k -flush_packets 1 \
            "$ALSA_DEVICE"
    fi
}

log "🎵 Starting REW RTP Bridge with auto-restart..."
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

# Check if ALSA device is available
if ! aplay -l 2>/dev/null | grep -q "Loopback"; then
    warning "ALSA Loopback device not found - continuing anyway"
fi

log "🎯 Ready for REW measurements!"
log "This bridge automatically restarts between measurements"
log "Perfect for REW sweeps, chirps, and other finite duration signals"
log "Press Ctrl+C to stop"
echo ""

# Main loop - restart FFmpeg when it exits (after each measurement)
instance=1
while true; do
    log "[$instance] Starting FFmpeg instance..."
    
    # Run FFmpeg - it will exit when RTP stream ends
    if run_ffmpeg_instance $instance; then
        success "[$instance] Measurement completed successfully"
    else
        exit_code=$?
        if [ $exit_code -eq 130 ]; then
            # Ctrl+C pressed
            log "Received interrupt signal"
            break
        fi
        warning "[$instance] FFmpeg exited with code $exit_code (normal for finite streams)"
    fi
    
    log "[$instance] Waiting ${RESTART_DELAY}s before ready for next measurement..."
    sleep $RESTART_DELAY
    instance=$((instance + 1))
    
    log "[$instance] Ready for next REW measurement!"
done

log "REW RTP Bridge stopped"
