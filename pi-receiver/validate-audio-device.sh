#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[VALIDATE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default configuration
AUDIO_DEVICE="${AUDIO_DEVICE:-hw:0,0}"
TEST_DURATION=3
TEST_FREQUENCY=1000
SAMPLE_RATE=48000
CHANNELS=2

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Validate audio device configuration for REW MediaMTX Audio Receiver"
    echo ""
    echo "Options:"
    echo "  -d, --device DEVICE     Audio device to test (default: hw:0,0)"
    echo "  -f, --frequency HZ      Test tone frequency (default: 1000)"
    echo "  -t, --duration SEC      Test duration in seconds (default: 3)"
    echo "  -r, --rate HZ           Sample rate (default: 48000)"
    echo "  -c, --channels NUM      Number of channels (default: 2)"
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
    echo "  $0 --device hw:1,0 --frequency 440 --duration 5"
    echo "  AUDIO_DEVICE=\"hw:CARD=sndrpimerusamp\" $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            AUDIO_DEVICE="$2"
            shift 2
            ;;
        -f|--frequency)
            TEST_FREQUENCY="$2"
            shift 2
            ;;
        -t|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -r|--rate)
            SAMPLE_RATE="$2"
            shift 2
            ;;
        -c|--channels)
            CHANNELS="$2"
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

log "🔊 Audio Device Validation"
log "Device: $AUDIO_DEVICE"
log "Sample rate: ${SAMPLE_RATE}Hz"
log "Channels: $CHANNELS"
log "Format: S32_LE (required for Merus amplifier)"
log "Test frequency: ${TEST_FREQUENCY}Hz"
log "Test duration: ${TEST_DURATION}s"

# Check if required tools are available
if ! command -v aplay >/dev/null 2>&1; then
    error "aplay command not found. Please install alsa-utils package."
    exit 1
fi

if ! command -v speaker-test >/dev/null 2>&1; then
    error "speaker-test command not found. Please install alsa-utils package."
    exit 1
fi

# Step 1: List available ALSA devices
log "Step 1: Listing available ALSA devices..."
if [ -f "/proc/asound/cards" ]; then
    cat /proc/asound/cards | sed 's/^/  /'
    echo ""
    
    # List detailed device information
    if command -v aplay >/dev/null 2>&1; then
        log "Detailed device list:"
        aplay -l 2>/dev/null | sed 's/^/  /' || warning "Failed to list detailed devices"
        echo ""
    fi
else
    warning "ALSA proc filesystem not available"
fi

# Step 2: Test device accessibility
log "Step 2: Testing device accessibility..."
if timeout 2 aplay -D "$AUDIO_DEVICE" --duration=0 /dev/zero 2>/dev/null; then
    success "✅ Device '$AUDIO_DEVICE' is accessible"
else
    error "❌ Device '$AUDIO_DEVICE' is not accessible"
    log "Trying alternative device names..."
    
    # Try common alternatives
    for alt_device in "hw:0,0" "hw:1,0" "plughw:0,0" "default"; do
        if [ "$alt_device" != "$AUDIO_DEVICE" ]; then
            log "  Testing: $alt_device"
            if timeout 2 aplay -D "$alt_device" --duration=0 /dev/zero 2>/dev/null; then
                success "  ✅ Alternative device '$alt_device' is accessible"
                warning "  Consider using '$alt_device' instead of '$AUDIO_DEVICE'"
            fi
        fi
    done
    echo ""
fi

# Step 3: Test audio playback with speaker-test
log "Step 3: Testing audio playback with speaker-test..."
log "Playing ${TEST_FREQUENCY}Hz tone for ${TEST_DURATION} seconds..."
log "You should hear a test tone if audio is working correctly."

echo ""
warning "▶️  Starting audio test - you should hear a ${TEST_FREQUENCY}Hz tone..."

if speaker-test -D "$AUDIO_DEVICE" -c "$CHANNELS" -r "$SAMPLE_RATE" -F S32_LE -t sine -f "$TEST_FREQUENCY" -l 1 -p "$((TEST_DURATION * 1000))" 2>/dev/null; then
    success "✅ Audio playback test completed successfully!"
else
    error "❌ Audio playback test failed"
    
    log "Attempting fallback tests..."
    # Try with different parameters
    for alt_device in "hw:0,0" "plughw:0,0" "default"; do
        if [ "$alt_device" != "$AUDIO_DEVICE" ]; then
            log "  Testing with device: $alt_device"
            if speaker-test -D "$alt_device" -c "$CHANNELS" -r "$SAMPLE_RATE" -F S32_LE -t sine -f "$TEST_FREQUENCY" -l 1 -p "2000" 2>/dev/null; then
                success "  ✅ Fallback test successful with '$alt_device'"
                warning "  Consider using '$alt_device' in your configuration"
                break
            fi
        fi
    done
fi

echo ""

# Step 4: Test with CamillaDSP configuration format
log "Step 4: Testing CamillaDSP-compatible format..."
if [ -f "camilladsp.yml" ]; then
    # Check if the device is configured in CamillaDSP
    if grep -q "device.*$AUDIO_DEVICE" camilladsp.yml; then
        success "✅ Device '$AUDIO_DEVICE' is configured in camilladsp.yml"
    else
        warning "⚠️  Device '$AUDIO_DEVICE' not found in camilladsp.yml"
        log "Current playback device in config:"
        grep -A 1 "playback:" camilladsp.yml | grep "device:" | sed 's/^/  /' || warning "Could not find playback device in config"
    fi
    
    # Test if CamillaDSP can validate the config
    if command -v camilladsp >/dev/null 2>&1; then
        log "Validating CamillaDSP configuration..."
        if camilladsp -c camilladsp.yml 2>/dev/null; then
            success "✅ CamillaDSP configuration is valid"
        else
            warning "⚠️  CamillaDSP configuration validation failed"
            log "You may need to adjust the device name or check ALSA setup"
        fi
    else
        warning "CamillaDSP not found - skipping configuration validation"
    fi
else
    warning "camilladsp.yml not found - skipping CamillaDSP validation"
fi

echo ""
log "🎵 Validation Summary"
log "====================================="
log "Device tested: $AUDIO_DEVICE"
log "Sample rate: ${SAMPLE_RATE}Hz"
log "Channels: $CHANNELS"

echo ""
log "Next steps:"
log "1. If audio test was successful, your device is ready"
log "2. Configure CamillaDSP: ./configure-audio-device.sh -d $AUDIO_DEVICE"
log "3. Start CamillaDSP: camilladsp -p 1234 camilladsp.yml"
log "4. Test the full pipeline with MediaMTX integration"

echo ""
warning "Manual validation required: Did you hear the test tone? (y/n)"
