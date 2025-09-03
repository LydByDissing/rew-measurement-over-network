#!/bin/bash

# Safe GUI Launcher for REW Audio Bridge
# Handles JavaFX rendering issues and provides fallback modes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
JAR_FILE="$SCRIPT_DIR/target/audio-bridge-0.1.0-SNAPSHOT.jar"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[GUI-LAUNCHER]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if JAR file exists
check_jar() {
    if [ ! -f "$JAR_FILE" ]; then
        error "JAR file not found: $JAR_FILE"
        echo "Please run: mvn clean package"
        exit 1
    fi
}

# Detect graphics environment
detect_graphics() {
    local has_display=false
    local has_x11=false
    local has_wayland=false
    
    if [ -n "$DISPLAY" ]; then
        has_display=true
        log "DISPLAY environment detected: $DISPLAY"
    fi
    
    if command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo >/dev/null 2>&1; then
        has_x11=true
        log "X11 server is available"
    fi
    
    if [ -n "$WAYLAND_DISPLAY" ]; then
        has_wayland=true
        log "Wayland display detected: $WAYLAND_DISPLAY"
    fi
    
    if ! $has_display && ! $has_x11 && ! $has_wayland; then
        warning "No graphics environment detected"
        return 1
    fi
    
    return 0
}

# Run in safe GUI mode with rendering fixes
run_gui_safe() {
    log "Starting GUI with safe rendering mode..."
    
    java \
        -Dprism.order=sw \
        -Dprism.text=t2k \
        -Dprism.allowhidpi=false \
        -Djava.awt.headless=false \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.base/java.util=ALL-UNNAMED \
        --add-opens java.desktop/java.awt.font=ALL-UNNAMED \
        -jar "$JAR_FILE" "$@"
}

# Run in headless mode
run_headless() {
    log "Starting in headless mode..."
    
    java \
        -Djava.awt.headless=true \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.base/java.util=ALL-UNNAMED \
        -jar "$JAR_FILE" --headless "$@"
}

# Run with hardware acceleration attempt
run_gui_hw() {
    log "Attempting hardware-accelerated GUI mode..."
    
    java \
        -Dprism.order=es2,d3d,sw \
        -Djava.awt.headless=false \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.base/java.util=ALL-UNNAMED \
        --add-opens java.desktop/java.awt.font=ALL-UNNAMED \
        -jar "$JAR_FILE" "$@"
}

# Main execution logic
main() {
    echo "REW Audio Bridge - Safe GUI Launcher"
    echo "==================================="
    
    check_jar
    
    local mode="${1:-auto}"
    
    case "$mode" in
        "headless"|"--headless")
            shift
            run_headless "$@"
            ;;
        "safe"|"--safe")
            shift
            if detect_graphics; then
                run_gui_safe "$@"
            else
                warning "No graphics available, falling back to headless mode"
                run_headless "$@"
            fi
            ;;
        "hardware"|"--hardware"|"hw")
            shift
            if detect_graphics; then
                run_gui_hw "$@" || {
                    warning "Hardware acceleration failed, falling back to safe mode"
                    run_gui_safe "$@"
                }
            else
                warning "No graphics available, falling back to headless mode"
                run_headless "$@"
            fi
            ;;
        "auto"|*)
            if [ "$mode" != "auto" ]; then
                # Pass through other arguments
                set -- "$mode" "$@"
            fi
            
            if detect_graphics; then
                log "Graphics detected, trying safe GUI mode first"
                run_gui_safe "$@" || {
                    warning "Safe GUI mode failed, falling back to headless"
                    run_headless "$@"
                }
            else
                log "No graphics detected, starting in headless mode"
                run_headless "$@"
            fi
            ;;
    esac
}

# Show usage if help requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [mode] [arguments...]"
    echo ""
    echo "Modes:"
    echo "  auto      Automatically detect best mode (default)"
    echo "  safe      Force safe GUI mode with software rendering"
    echo "  hardware  Attempt hardware acceleration, fallback to safe"
    echo "  headless  Force headless/CLI mode"
    echo ""
    echo "Arguments are passed through to the application:"
    echo "  --target IP    Target Pi device IP"
    echo "  --port PORT    RTP port (default: 5005)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Auto-detect mode"
    echo "  $0 safe                     # Force safe GUI mode"
    echo "  $0 headless --target 192.168.1.100"
    echo "  $0 --target 192.168.1.50 --port 6000"
    exit 0
fi

# Run main function
main "$@"