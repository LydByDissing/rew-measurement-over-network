#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[CONFIG]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default configuration
AUDIO_DEVICE="${AUDIO_DEVICE:-hw:0,0}"
CONFIG_FILE="${CONFIG_FILE:-camilladsp.yml}"
TEMPLATE_FILE="${TEMPLATE_FILE:-camilladsp.yml.template}"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Configure CamillaDSP audio device for REW MediaMTX Audio Receiver"
    echo ""
    echo "Options:"
    echo "  -d, --device DEVICE     Audio device (default: hw:0,0)"
    echo "  -c, --config FILE       Output config file (default: camilladsp.yml)"
    echo "  -t, --template FILE     Template file (default: camilladsp.yml.template)"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Common audio devices:"
    echo "  hw:0,0                        Default audio device"
    echo "  hw:CARD=sndrpimerusamp        Raspberry Pi Merus amplifier"
    echo "  plughw:0,0                    ALSA plug layer device"
    echo "  default                       ALSA default device"
    echo ""
    echo "Examples:"
    echo "  $0 -d \"hw:CARD=sndrpimerusamp\""
    echo "  $0 --device hw:1,0 --config my-config.yml"
    echo "  AUDIO_DEVICE=\"hw:CARD=sndrpimerusamp\" $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            AUDIO_DEVICE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE_FILE="$2"
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

log "🎵 Configuring CamillaDSP Audio Device"
log "Audio device: $AUDIO_DEVICE"
log "Template file: $TEMPLATE_FILE"
log "Output config: $CONFIG_FILE"

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Generate configuration from template
log "Generating CamillaDSP configuration..."
export AUDIO_DEVICE
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    success "✅ Configuration generated successfully: $CONFIG_FILE"
    log "Audio device configured: $AUDIO_DEVICE"
else
    error "❌ Failed to generate configuration"
    exit 1
fi

# Show the relevant section of the generated config
log "Generated playback device configuration:"
grep -A 4 "playback:" "$CONFIG_FILE" | sed 's/^/  /'

# Verify the audio device is available (if running on Pi)
if [ -f "/proc/asound/cards" ]; then
    log "Available ALSA cards:"
    cat /proc/asound/cards | sed 's/^/  /'
    
    # Try to check if the specific device is accessible
    if command -v aplay >/dev/null 2>&1; then
        log "Testing device accessibility..."
        if aplay -D "$AUDIO_DEVICE" --duration=0 /dev/zero 2>/dev/null; then
            success "✅ Audio device '$AUDIO_DEVICE' is accessible"
        else
            warning "⚠️  Audio device '$AUDIO_DEVICE' may not be accessible"
            warning "   This might be normal if the device is not connected or needs specific setup"
        fi
    fi
else
    warning "Not running on a system with ALSA proc filesystem (development environment?)"
fi

echo ""
log "Next steps:"
log "1. Run audio validation: ./validate-audio-device.sh -d $AUDIO_DEVICE"
log "2. Test with speaker-test: speaker-test -D $AUDIO_DEVICE -c 2 -r 48000"
log "3. Start CamillaDSP: camilladsp -p 1234 $CONFIG_FILE"
