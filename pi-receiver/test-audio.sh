#!/bin/sh

# Audio Test Utility for REW Pi Receiver Container
# Tests the complete audio chain: ALSA → CamillaDSP → Audio Output
# Usage: ./test-audio.sh [test_type]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SAMPLE_RATE=48000
CHANNELS=2
DURATION=3
FREQUENCY=1000

log() {
    echo -e "${BLUE}[AUDIO-TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test if we're running in a container
check_container_environment() {
    log "Checking container environment..."

    if [ -f /.dockerenv ]; then
        success "Running inside Docker container"
    else
        warning "Not running in Docker container"
    fi

    if [ "$(whoami)" = "root" ]; then
        success "Running as root (good for device access)"
    else
        warning "Not running as root - audio device access may be limited"
    fi
}

# Test ALSA subsystem
test_alsa_system() {
    log "Testing ALSA audio subsystem..."

    # Check if ALSA is available
    if ! command -v aplay &> /dev/null; then
        error "aplay command not found - ALSA tools not installed"
        return 1
    fi

    # List audio devices
    log "Available audio devices:"
    aplay -l 2>/dev/null || {
        error "No audio devices found"
        return 1
    }

    # Check for loopback device
    if aplay -l 2>/dev/null | grep -q "Loopback"; then
        success "ALSA Loopback device found"
    else
        warning "ALSA Loopback device not found"
        log "Loading snd-aloop module..."
        modprobe snd-aloop 2>/dev/null || warning "Could not load snd-aloop module"
    fi

    # Test default device
    log "Testing default audio device..."
    if aplay -D default --duration=1 --quiet /dev/zero 2>/dev/null; then
        success "Default audio device is accessible"
    else
        error "Default audio device is not accessible"
        return 1
    fi

    return 0
}

# Test tone generation and playback
test_tone_generation() {
    local device=${1:-"default"}
    local freq=${2:-$FREQUENCY}
    local duration=${3:-$DURATION}

    log "Testing tone generation to device: $device"
    log "Frequency: ${freq}Hz, Duration: ${duration}s, Sample Rate: ${SAMPLE_RATE}Hz"

    if ! command -v speaker-test &> /dev/null; then
        warning "speaker-test not available, using alternative method"
        test_tone_generation_ffmpeg "$device" "$freq" "$duration"
        return $?
    fi

    log "Playing test tone..."
    echo "🔊 You should hear a ${freq}Hz tone for ${duration} seconds"

    if speaker-test -D "$device" -c $CHANNELS -r $SAMPLE_RATE -t sine -f "$freq" -l 1 -p "${duration}000" 2>/dev/null; then
        success "Tone generation completed successfully"
        return 0
    else
        error "Tone generation failed"
        return 1
    fi
}

# Alternative tone generation using ffmpeg
test_tone_generation_ffmpeg() {
    local device=${1:-"default"}
    local freq=${2:-$FREQUENCY}
    local duration=${3:-$DURATION}

    if ! command -v ffmpeg &> /dev/null; then
        error "Neither speaker-test nor ffmpeg available for tone generation"
        return 1
    fi

    log "Using ffmpeg for tone generation..."
    echo "🔊 You should hear a ${freq}Hz tone for ${duration} seconds"

    if ffmpeg -f lavfi -i "sine=frequency=${freq}:sample_rate=${SAMPLE_RATE}:duration=${duration}" \
       -f alsa -ac $CHANNELS -ar $SAMPLE_RATE "$device" -y 2>/dev/null; then
        success "FFmpeg tone generation completed successfully"
        return 0
    else
        error "FFmpeg tone generation failed"
        return 1
    fi
}

# Test CamillaDSP integration
test_camilladsp_integration() {
    log "Testing CamillaDSP integration..."

    # Check if CamillaDSP is available
    if ! command -v camilladsp &> /dev/null; then
        warning "CamillaDSP not found in PATH"
        return 1
    fi

    # Check if config file exists
    local config_file="/app/camilladsp.yml"
    if [ ! -f "$config_file" ]; then
        warning "CamillaDSP config file not found at $config_file"
        return 1
    fi

    log "CamillaDSP config file found: $config_file"

    # Validate config file
    if camilladsp -c "$config_file" --check 2>/dev/null; then
        success "CamillaDSP configuration is valid"
    else
        error "CamillaDSP configuration validation failed"
        return 1
    fi

    # Check if CamillaDSP is running
    if pgrep -f camilladsp > /dev/null; then
        success "CamillaDSP process is running"

        # Test CamillaDSP API if available
        if command -v curl &> /dev/null; then
            log "Testing CamillaDSP API..."
            if curl -s http://localhost:1234/api/version >/dev/null 2>&1; then
                success "CamillaDSP API is responding"
            else
                warning "CamillaDSP API not responding (may not be enabled)"
            fi
        fi
    else
        warning "CamillaDSP process not running"
    fi

    return 0
}

# Test ALSA loopback specifically
test_alsa_loopback() {
    log "Testing ALSA loopback device..."

    # Check if loopback module is loaded
    if lsmod | grep -q snd_aloop; then
        success "snd-aloop module is loaded"
    else
        warning "snd-aloop module not loaded, attempting to load..."
        if modprobe snd-aloop 2>/dev/null; then
            success "Successfully loaded snd-aloop module"
        else
            error "Failed to load snd-aloop module"
            return 1
        fi
    fi

    # Test loopback device specifically
    log "Testing loopback device hw:Loopback,0,0..."

    if aplay -D hw:Loopback,0,0 --duration=1 --quiet /dev/zero 2>/dev/null; then
        success "Loopback device hw:Loopback,0,0 is accessible"
    else
        error "Loopback device hw:Loopback,0,0 is not accessible"

        # Try alternative loopback device names
        log "Trying alternative loopback device names..."
        for device in "hw:0,0" "hw:1,0" "plughw:Loopback,0,0"; do
            log "Testing $device..."
            if aplay -D "$device" --duration=1 --quiet /dev/zero 2>/dev/null; then
                success "Alternative loopback device $device is accessible"
                echo "💡 Use device '$device' in MediaMTX configuration"
                return 0
            fi
        done

        return 1
    fi

    return 0
}

# Test MediaMTX integration
test_mediamtx_integration() {
    log "Testing MediaMTX integration..."

    # Check if MediaMTX is running
    if pgrep -f mediamtx > /dev/null; then
        success "MediaMTX process is running"
    else
        warning "MediaMTX process not running"
        return 1
    fi

    # Test MediaMTX API
    if command -v curl &> /dev/null; then
        log "Testing MediaMTX API..."

        if curl -s http://localhost:9997/v3/config >/dev/null 2>&1; then
            success "MediaMTX API is responding"

            # Check paths configuration
            log "Checking MediaMTX paths configuration..."
            local paths_count=$(curl -s http://localhost:9997/v3/paths 2>/dev/null | grep -o '"name"' | wc -l || echo "0")
            log "MediaMTX configured paths: $paths_count"

        else
            error "MediaMTX API not responding"
            return 1
        fi
    else
        warning "curl not available for API testing"
    fi

    # Test if RTP port is listening
    if command -v netstat &> /dev/null; then
        log "Checking if RTP port 5004 is listening..."
        if netstat -ulpn 2>/dev/null | grep -q ":5004 "; then
            success "Port 5004 is listening for RTP streams"
        else
            warning "Port 5004 is not listening - MediaMTX may not be configured for RTP"
        fi
    fi

    return 0
}

# Full system test
test_full_system() {
    log "Running full system audio test..."

    local success_count=0
    local total_tests=5

    # Test 1: ALSA System
    if test_alsa_system; then
        ((success_count++))
    fi

    # Test 2: ALSA Loopback
    if test_alsa_loopback; then
        ((success_count++))
    fi

    # Test 3: Tone Generation
    if test_tone_generation "default"; then
        ((success_count++))
    fi

    # Test 4: CamillaDSP
    if test_camilladsp_integration; then
        ((success_count++))
    fi

    # Test 5: MediaMTX
    if test_mediamtx_integration; then
        ((success_count++))
    fi

    echo
    log "===== AUDIO TEST SUMMARY ====="
    log "Passed: $success_count/$total_tests tests"

    if [ "$success_count" -eq "$total_tests" ]; then
        success "✅ All audio tests passed! Audio system is working correctly."
        echo
        log "🎵 Your Pi is ready to receive RTP audio streams on port 5004"
        log "🔗 Configure REW to send RTP to: $(hostname -I | awk '{print $1}'):5004"
        return 0
    else
        error "❌ Some audio tests failed. Check the output above for details."
        return 1
    fi
}

# Interactive test menu
show_test_menu() {
    echo
    log "===== AUDIO TEST UTILITY ====="
    echo "1) Full System Test (recommended)"
    echo "2) ALSA System Test"
    echo "3) ALSA Loopback Test"
    echo "4) Play Test Tone (default device)"
    echo "5) Play Test Tone (loopback device)"
    echo "6) CamillaDSP Integration Test"
    echo "7) MediaMTX Integration Test"
    echo "8) Environment Check"
    echo "9) Exit"
    echo
    read -p "Select test (1-9): " choice

    case $choice in
        1) test_full_system ;;
        2) test_alsa_system ;;
        3) test_alsa_loopback ;;
        4) test_tone_generation "default" ;;
        5) test_tone_generation "hw:Loopback,0,0" ;;
        6) test_camilladsp_integration ;;
        7) test_mediamtx_integration ;;
        8) check_container_environment ;;
        9) log "Exiting..."; exit 0 ;;
        *) error "Invalid choice"; show_test_menu ;;
    esac
}

# Main script logic
main() {
    echo "🎵 REW Pi Audio Test Utility"
    echo "============================"

    case "${1:-}" in
        "full"|"all")
            test_full_system
            ;;
        "alsa")
            test_alsa_system
            ;;
        "loopback")
            test_alsa_loopback
            ;;
        "tone")
            test_tone_generation "${2:-default}" "${3:-$FREQUENCY}" "${4:-$DURATION}"
            ;;
        "camilladsp")
            test_camilladsp_integration
            ;;
        "mediamtx")
            test_mediamtx_integration
            ;;
        "env")
            check_container_environment
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [test_type]"
            echo ""
            echo "Test Types:"
            echo "  full      - Run all tests (default)"
            echo "  alsa      - Test ALSA audio system"
            echo "  loopback  - Test ALSA loopback device"
            echo "  tone      - Play test tone [device] [freq] [duration]"
            echo "  camilladsp - Test CamillaDSP integration"
            echo "  mediamtx  - Test MediaMTX integration"
            echo "  env       - Check container environment"
            echo "  help      - Show this help"
            echo ""
            echo "Interactive mode (no arguments):"
            echo "  $0"
            ;;
        "")
            show_test_menu
            ;;
        *)
            error "Unknown test type: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"