#!/bin/bash

# Diagnose the audio pipeline configuration issues
# Shows where the audio routing is broken

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[DIAGNOSE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🔍 Audio Pipeline Configuration Diagnosis"
echo ""

# Check current CamillaDSP configuration
log "1. CamillaDSP Configuration Analysis"
if [ -f "camilladsp.yml" ]; then
    success "✅ CamillaDSP config found"
    
    log "Capture device:"
    grep -A3 "capture:" camilladsp.yml | sed 's/^/    /'
    
    log "Playback device:"
    grep -A3 "playback:" camilladsp.yml | sed 's/^/    /'
    
    # Check if it's configured for Merus amp
    if grep -q "sndrpimerusamp" camilladsp.yml; then
        success "✅ Configured for Merus amplifier"
    else
        warning "⚠️  NOT configured for Merus amplifier"
        PLAYBACK_DEVICE=$(grep -A3 "playback:" camilladsp.yml | grep "device:" | cut -d'"' -f2)
        log "Current playback device: $PLAYBACK_DEVICE"
    fi
    
    # Check capture source
    CAPTURE_DEVICE=$(grep -A3 "capture:" camilladsp.yml | grep "device:" | cut -d'"' -f2)
    log "Current capture device: $CAPTURE_DEVICE"
    
    if [[ "$CAPTURE_DEVICE" == *"Loopback"* ]]; then
        log "✅ Configured to capture from ALSA loopback"
    else
        warning "⚠️  NOT capturing from ALSA loopback"
    fi
else
    error "❌ CamillaDSP configuration not found"
fi

echo ""

# Check MediaMTX configuration
log "2. MediaMTX Configuration Analysis"
MEDIAMTX_CONFIG=""
if [ -f "mediamtx-rtp.yml" ]; then
    MEDIAMTX_CONFIG="mediamtx-rtp.yml"
elif [ -f "mediamtx.yml" ]; then
    MEDIAMTX_CONFIG="mediamtx.yml"
fi

if [ -n "$MEDIAMTX_CONFIG" ]; then
    success "✅ MediaMTX config found: $MEDIAMTX_CONFIG"
    
    # Check for RTP input
    if grep -q "rtp://" "$MEDIAMTX_CONFIG"; then
        success "✅ RTP input configured"
        grep "source.*rtp" "$MEDIAMTX_CONFIG" | sed 's/^/    /'
    else
        warning "⚠️  No RTP input found"
    fi
    
    # Check for ALSA output
    if grep -q "alsa\|Loopback" "$MEDIAMTX_CONFIG"; then
        success "✅ ALSA/Loopback output configured"
        grep -i "alsa\|loopback" "$MEDIAMTX_CONFIG" | sed 's/^/    /'
    else
        error "❌ NO ALSA/Loopback output configured"
        log "This is the main issue! MediaMTX receives RTP but doesn't output to ALSA."
    fi
else
    error "❌ MediaMTX configuration not found"
fi

echo ""

# Check ALSA system
log "3. ALSA System Analysis"
if [ -f "/proc/asound/cards" ]; then
    log "Available audio cards:"
    cat /proc/asound/cards | sed 's/^/    /'
    
    # Check for loopback device
    if grep -q "Loopback" /proc/asound/cards; then
        success "✅ ALSA loopback device available"
    else
        error "❌ ALSA loopback device not found"
        log "Need to load snd-aloop module"
    fi
    
    # Check for Merus amplifier
    if grep -q "sndrpimerusamp" /proc/asound/cards; then
        success "✅ Merus amplifier detected"
    else
        warning "⚠️  Merus amplifier not detected"
    fi
else
    error "❌ ALSA system not accessible"
fi

echo ""

# Show current audio pipeline
log "4. Current Audio Pipeline"
echo ""
log "📊 Expected Pipeline:"
log "   RTP (port 5004) → MediaMTX → ALSA Loopback → CamillaDSP → Merus Amp"
echo ""

log "🔧 Current Pipeline:"
if [[ "$CAPTURE_DEVICE" == *"Loopback"* ]]; then
    log "   RTP (port 5004) → MediaMTX → ❌ NO OUTPUT → [BROKEN] → CamillaDSP (waiting for input) → Merus Amp"
else
    log "   RTP (port 5004) → MediaMTX → ❌ NO OUTPUT"
    log "   [SEPARATE] Unknown source → CamillaDSP → Merus Amp"
fi

echo ""

# Recommendations
log "5. Recommendations"
echo ""

if ! grep -q "alsa\|Loopback" "$MEDIAMTX_CONFIG" 2>/dev/null; then
    error "🔧 CRITICAL: MediaMTX is not outputting to ALSA"
    log "Solutions:"
    log "1. Add ALSA output to MediaMTX configuration"
    log "2. Use simpler direct RTP → CamillaDSP approach"
    log "3. Fix the MediaMTX → ALSA loopback connection"
fi

if ! grep -q "sndrpimerusamp" camilladsp.yml 2>/dev/null; then
    warning "🔧 CamillaDSP not configured for Merus amplifier"
    log "Fix: Run ./configure-audio-device.sh -d hw:CARD=sndrpimerusamp"
fi

echo ""
log "🎯 Quick Fix Commands:"
log "1. Configure CamillaDSP for Merus: ./configure-audio-device.sh -d hw:CARD=sndrpimerusamp"
log "2. Test direct audio: speaker-test -D hw:CARD=sndrpimerusamp -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1"
log "3. Debug CamillaDSP: ./debug-camilladsp.sh"
