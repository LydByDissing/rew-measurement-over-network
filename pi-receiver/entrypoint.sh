#!/bin/bash
#
# REW Pi Audio Receiver Docker Entrypoint
# Handles container initialization and service startup
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[ENTRYPOINT]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Container startup banner
echo "🐳 REW Pi Audio Receiver Container"
echo "=================================="
echo "Python version: $(python --version)"
echo "Container architecture: $(uname -m)"
echo "Container hostname: $(hostname)"
echo "Container IP: $(hostname -i 2>/dev/null || echo 'Not available')"
echo

# Environment info
log "Environment configuration:"
echo "  RTP Port: ${RTP_PORT:-5004}"
echo "  HTTP Port: ${HTTP_PORT:-8080}"
echo "  Audio Device: ${AUDIO_DEVICE:-default}"
echo "  Log Level: ${LOG_LEVEL:-INFO}"
echo "  Python Path: $(which python)"

# Check if we're running in Docker
if [ -f /.dockerenv ]; then
    log "Running in Docker container"
    DOCKER_MODE=true
else
    log "Running in native environment"
    DOCKER_MODE=false
fi

# Audio system initialization
initialize_audio() {
    log "Initializing audio system..."
    
    if $DOCKER_MODE; then
        # In Docker, we typically use null device or pulse socket
        log "Docker audio mode - checking available devices"
        
        # List available audio devices
        if command -v aplay >/dev/null 2>&1; then
            echo "Available audio devices:"
            aplay -l 2>/dev/null || echo "  No hardware audio devices found (expected in container)"
        fi
        
        # Check for PulseAudio socket
        if [ -S /run/pulse/native ]; then
            log "PulseAudio socket found - enabling pulse audio"
            export PULSE_SERVER="unix:/run/pulse/native"
        else
            log "No PulseAudio socket - using null audio device"
        fi
    else
        # Native Pi environment
        log "Native Pi audio mode - initializing ALSA"
        
        # Ensure audio group membership (if running as root)
        if [ "$(id -u)" = "0" ]; then
            warning "Running as root - audio permissions may be limited"
        fi
        
        # List and test audio devices
        if command -v aplay >/dev/null 2>&1; then
            echo "Available audio devices:"
            aplay -l || warning "Could not list audio devices"
        fi
    fi
}

# Network configuration
configure_network() {
    log "Configuring network settings..."
    
    # mDNS/Avahi configuration
    if $DOCKER_MODE; then
        log "Container networking - mDNS discovery enabled"
        # In container mode, rely on host networking or service discovery
    else
        log "Native networking - checking Avahi daemon"
        if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
            success "Avahi daemon is running"
        else
            warning "Avahi daemon not running - mDNS discovery may not work"
        fi
    fi
    
    # Display network info
    echo "Network configuration:"
    echo "  Hostname: $(hostname)"
    echo "  IP Address: $(hostname -i 2>/dev/null || echo 'Multiple/Unknown')"
    if command -v ip >/dev/null 2>&1; then
        echo "  Network interfaces:"
        ip addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "    " $NF ": " $2}' || true
    fi
}

# Health check setup
setup_monitoring() {
    log "Setting up health monitoring..."
    
    # Create log directory if it doesn't exist
    mkdir -p /var/log/rew 2>/dev/null || true
    
    # Set up log rotation for container
    if $DOCKER_MODE; then
        log "Container logging - stdout/stderr capture enabled"
    else
        log "Native logging - file-based logging enabled"
    fi
}

# Signal handlers for graceful shutdown
cleanup() {
    log "Received shutdown signal - cleaning up..."
    
    # Kill Python process gracefully
    if [ -n "$PYTHON_PID" ]; then
        log "Stopping Python receiver (PID: $PYTHON_PID)"
        kill -TERM "$PYTHON_PID" 2>/dev/null || true
        wait "$PYTHON_PID" 2>/dev/null || true
    fi
    
    success "Shutdown complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main initialization
main() {
    log "Starting REW Pi Audio Receiver initialization..."
    
    initialize_audio
    configure_network
    setup_monitoring
    
    success "Initialization complete - starting audio receiver"
    echo
    
    # Start the Python receiver with provided arguments
    log "Executing: python rew_audio_receiver.py $*"
    python rew_audio_receiver.py "$@" &
    PYTHON_PID=$!
    
    # Wait for the process
    wait $PYTHON_PID
}

# Help message
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "REW Pi Audio Receiver Docker Entrypoint"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --device DEVICE        Audio device (default: default)"
    echo "  --rtp-port PORT        RTP listening port (default: 5004)"
    echo "  --http-port PORT       HTTP status port (default: 8080)"
    echo "  --verbose              Enable verbose logging"
    echo "  --help, -h             Show this help message"
    echo
    echo "Environment Variables:"
    echo "  RTP_PORT              RTP listening port"
    echo "  HTTP_PORT             HTTP status port"
    echo "  AUDIO_DEVICE          Audio output device"
    echo "  LOG_LEVEL             Logging level (DEBUG, INFO, WARNING, ERROR)"
    echo
    echo "Examples:"
    echo "  $0 --device hw:0,0 --verbose"
    echo "  $0 --rtp-port 5005 --http-port 8081"
    exit 0
fi

# Run main function
main "$@"