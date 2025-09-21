#!/bin/bash

# Quick dependency check for REW MediaMTX Audio Receiver
# This script checks if required tools are available

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[CHECK]${NC} $1"; }
error() { echo -e "${RED}[MISSING]${NC} $1"; }
success() { echo -e "${GREEN}[FOUND]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🔍 Checking dependencies for REW MediaMTX Audio Receiver..."
echo ""

MISSING_COUNT=0

# Check critical dependencies
CRITICAL_DEPS=(
    "ffmpeg:RTP stream generation and media processing"
    "aplay:ALSA audio playback testing"
    "speaker-test:Direct audio device testing"
    "envsubst:Configuration template processing"
    "curl:API endpoint testing"
)

log "Critical dependencies:"
for dep_info in "${CRITICAL_DEPS[@]}"; do
    cmd="${dep_info%%:*}"
    desc="${dep_info#*:}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        success "✅ $cmd - $desc"
    else
        error "❌ $cmd - $desc"
        ((MISSING_COUNT++))
    fi
done

echo ""

# Check optional dependencies
OPTIONAL_DEPS=(
    "nc:Network connectivity testing"
    "jq:JSON processing for API responses"
    "pulseaudio:PulseAudio utilities"
)

log "Optional dependencies:"
for dep_info in "${OPTIONAL_DEPS[@]}"; do
    cmd="${dep_info%%:*}"
    desc="${dep_info#*:}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        success "✅ $cmd - $desc"
    else
        warning "⚠️  $cmd - $desc (optional)"
    fi
done

echo ""
log "Summary:"
if [ $MISSING_COUNT -eq 0 ]; then
    success "✅ All critical dependencies are available!"
    echo ""
    log "Ready to test:"
    log "• Test Merus amp: ./test-merus-amp.sh"
    log "• Test full pipeline: ./test-full-pipeline.sh"
    log "• Test RTP streaming: ./test-rtp-stream.sh"
else
    error "❌ $MISSING_COUNT critical dependencies are missing"
    echo ""
    log "To install missing dependencies:"
    log "• Run: ./install-dependencies.sh"
    log "• Or install manually: sudo apt-get update && sudo apt-get install ffmpeg alsa-utils curl gettext-base"
fi

echo ""
log "Audio system check:"
if [ -f "/proc/asound/cards" ]; then
    CARDS_COUNT=$(grep -c "^[[:space:]]*[0-9]" /proc/asound/cards 2>/dev/null || echo "0")
    if [ "$CARDS_COUNT" -gt 0 ]; then
        success "✅ $CARDS_COUNT audio card(s) detected"
        if grep -q "sndrpimerusamp" /proc/asound/cards 2>/dev/null; then
            success "✅ Merus amplifier detected"
        else
            warning "⚠️  Merus amplifier not detected in /proc/asound/cards"
        fi
    else
        error "❌ No audio cards detected"
    fi
else
    error "❌ ALSA proc filesystem not available"
fi
