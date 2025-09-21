#!/bin/bash

# Diagnose the current audio environment and provide recommendations
# This script helps identify if we're on the Pi vs development machine

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

log "🔍 Audio Environment Diagnostic"
echo ""

# Check system type
log "System Information:"
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    log "Device: $MODEL"
    if [[ "$MODEL" == *"Raspberry Pi"* ]]; then
        success "✅ Running on Raspberry Pi"
        IS_PI=true
    else
        warning "⚠️  Not running on Raspberry Pi"
        IS_PI=false
    fi
else
    warning "⚠️  Device model not detected (probably not a Pi)"
    IS_PI=false
fi

# Check audio devices
echo ""
log "Audio Devices:"
if [ -f /proc/asound/cards ]; then
    cat /proc/asound/cards | while read line; do
        if [[ "$line" =~ ^[[:space:]]*[0-9] ]]; then
            log "  $line"
        fi
    done
    
    # Check for Merus amplifier specifically
    if grep -q "sndrpimerusamp" /proc/asound/cards 2>/dev/null; then
        success "✅ Merus amplifier detected"
        HAS_MERUS=true
    else
        warning "⚠️  Merus amplifier not detected"
        HAS_MERUS=false
    fi
else
    error "❌ No audio system detected"
    HAS_MERUS=false
fi

# Check services
echo ""
log "Service Status:"
if pgrep -f mediamtx >/dev/null; then
    success "✅ MediaMTX running"
    MEDIAMTX_RUNNING=true
else
    warning "⚠️  MediaMTX not running"
    MEDIAMTX_RUNNING=false
fi

if pgrep -f camilladsp >/dev/null; then
    success "✅ CamillaDSP running"  
    CAMILLADSP_RUNNING=true
else
    warning "⚠️  CamillaDSP not running"
    CAMILLADSP_RUNNING=false
fi

# Check dependencies
echo ""
log "Dependencies:"
DEPS=("ffmpeg" "aplay" "speaker-test" "curl")
for dep in "${DEPS[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        success "✅ $dep available"
    else
        warning "⚠️  $dep missing"
    fi
done

# Provide recommendations
echo ""
log "🎯 Recommendations:"

if [ "$IS_PI" = false ]; then
    echo ""
    warning "🖥️  DEVELOPMENT ENVIRONMENT DETECTED"
    log "You're not running on the Raspberry Pi with the Merus amplifier."
    log ""
    log "To test the complete audio pipeline:"
    log "1. Deploy to Pi: ./deploy-to-pi.sh deploy-remote pi@192.168.1.254"
    log "2. SSH to Pi: ssh pi@192.168.1.254"
    log "3. Navigate: cd /home/pi/rew-receiver"
    log "4. Test pipeline: ./test-full-pipeline.sh"
    log "5. Test RTP: ./test-rtp-stream.sh"
    echo ""
    log "For development testing on this machine:"
    log "• Test with available audio devices:"
    if grep -q "HDA\|USB-Audio" /proc/asound/cards 2>/dev/null; then
        AVAILABLE_CARD=$(awk '/^[[:space:]]*[0-9]/ {match($0, /\[[^]]+\]/); print substr($0, RSTART+1, RLENGTH-2); exit}' /proc/asound/cards 2>/dev/null)
        if [ -n "$AVAILABLE_CARD" ]; then
            log "  speaker-test -D \"hw:CARD=$AVAILABLE_CARD\" -c 2 -t sine -f 1000 -l 1"
        fi
    fi
else
    if [ "$HAS_MERUS" = false ]; then
        echo ""
        error "🔧 MERUS AMPLIFIER NOT DETECTED"
        log "The Merus amplifier is not available on this Pi."
        log ""
        log "Troubleshooting steps:"
        log "1. Check hardware connection"
        log "2. Check device tree overlay in /boot/config.txt"
        log "3. Reboot after hardware changes"
        log "4. Check dmesg for hardware detection logs"
    else
        if [ "$MEDIAMTX_RUNNING" = false ] || [ "$CAMILLADSP_RUNNING" = false ]; then
            echo ""
            warning "🚀 SERVICES NOT RUNNING"
            log "Start the complete pipeline:"
            log "./test-full-pipeline.sh"
        else
            echo ""
            success "🎵 READY FOR TESTING"
            log "All components detected and running!"
            log ""
            log "Test commands:"
            log "• Test Merus amp: ./test-merus-amp.sh"
            log "• Test RTP stream: ./test-rtp-stream.sh"
            log "• Test full pipeline: ./test-full-pipeline.sh"
        fi
    fi
fi

echo ""
log "📋 Current Configuration Summary:"
log "• Environment: $([ "$IS_PI" = true ] && echo "Raspberry Pi" || echo "Development Machine")"
log "• Merus Amp: $([ "$HAS_MERUS" = true ] && echo "Available" || echo "Not Available")"
log "• MediaMTX: $([ "$MEDIAMTX_RUNNING" = true ] && echo "Running" || echo "Stopped")"
log "• CamillaDSP: $([ "$CAMILLADSP_RUNNING" = true ] && echo "Running" || echo "Stopped")"
