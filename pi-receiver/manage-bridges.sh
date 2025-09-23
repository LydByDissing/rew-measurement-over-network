#!/bin/bash

# Bridge Management Script - Easy control of RTP/UDP bridges

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[BRIDGE-MGR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Bridge options
RTP_BRIDGES=(
    "rtp-bridge-manual.sh:Manual RTP Bridge (user controlled)"
    "rew-rtp-bridge.sh:REW-Specific RTP Bridge (auto-restart)"
    "rew-rtp-robust.sh:Ultra-Robust RTP Bridge (packet loss tolerant)"
    "rtp-to-alsa.sh:Standard RTP Bridge (systemd service)"
)

UDP_BRIDGE="udp-to-alsa.sh:UDP Bridge (port 8000)"

# Function to show running bridges
show_status() {
    log "🔍 Bridge Status Check"
    echo ""
    
    log "RTP Bridges (port 5004):"
    for bridge_info in "${RTP_BRIDGES[@]}"; do
        bridge_script="${bridge_info%%:*}"
        bridge_desc="${bridge_info##*:}"
        
        if pgrep -f "$bridge_script" >/dev/null; then
            success "✅ $bridge_desc - RUNNING (PID: $(pgrep -f "$bridge_script"))"
        else
            log "⚪ $bridge_desc - stopped"
        fi
    done
    
    echo ""
    log "UDP Bridge (port 8000):"
    bridge_script="${UDP_BRIDGE%%:*}"
    bridge_desc="${UDP_BRIDGE##*:}"
    
    if pgrep -f "$bridge_script" >/dev/null; then
        success "✅ $bridge_desc - RUNNING (PID: $(pgrep -f "$bridge_script"))"
    else
        log "⚪ $bridge_desc - stopped"
    fi
    
    echo ""
}

# Function to stop all bridges
stop_all() {
    log "🛑 Stopping all bridges..."
    
    # Stop RTP bridges
    for bridge_info in "${RTP_BRIDGES[@]}"; do
        bridge_script="${bridge_info%%:*}"
        if pgrep -f "$bridge_script" >/dev/null; then
            pkill -f "$bridge_script" && success "Stopped $bridge_script"
        fi
    done
    
    # Stop UDP bridge
    bridge_script="${UDP_BRIDGE%%:*}"
    if pgrep -f "$bridge_script" >/dev/null; then
        pkill -f "$bridge_script" && success "Stopped $bridge_script"
    fi
    
    # Stop systemd services
    sudo systemctl stop rtp-bridge >/dev/null 2>&1 && success "Stopped systemd RTP bridge service" || true
    sudo systemctl stop udp-bridge >/dev/null 2>&1 && success "Stopped systemd UDP bridge service" || true
    
    sleep 2
    show_status
}

# Function to start a specific bridge
start_bridge() {
    local bridge_script="$1"
    local bridge_desc="$2"
    
    log "🚀 Starting: $bridge_desc"
    
    # Stop only conflicting RTP bridges if starting an RTP bridge
    if [[ "$bridge_script" == *"rtp"* ]]; then
        log "Stopping conflicting RTP bridges..."
        for bridge_info in "${RTP_BRIDGES[@]}"; do
            conflict_script="${bridge_info%%:*}"
            if [[ "$conflict_script" != "$bridge_script" ]] && pgrep -f "$conflict_script" >/dev/null; then
                pkill -f "$conflict_script" && log "Stopped conflicting $conflict_script"
            fi
        done
        # Stop systemd RTP service
        sudo systemctl stop rtp-bridge >/dev/null 2>&1 || true
    fi
    
    # Stop UDP bridge only if starting UDP bridge
    if [[ "$bridge_script" == *"udp"* ]]; then
        log "Stopping conflicting UDP bridge..."
        udp_script="${UDP_BRIDGE%%:*}"
        if pgrep -f "$udp_script" >/dev/null; then
            pkill -f "$udp_script" && log "Stopped conflicting $udp_script"
        fi
        # Stop systemd UDP service
        sudo systemctl stop udp-bridge >/dev/null 2>&1 || true
    fi
    
    if [ -f "/home/pi/rew-receiver/$bridge_script" ]; then
        "/home/pi/rew-receiver/$bridge_script" &
        sleep 2
        success "Started: $bridge_desc"
        show_status
    else
        error "Bridge script not found: $bridge_script"
        return 1
    fi
}

# Function to show menu
show_menu() {
    clear
    log "🎵 RTP/UDP Bridge Manager"
    echo ""
    
    show_status
    
    echo ""
    log "Available Actions:"
    echo ""
    echo "RTP Bridges (Choose One):"
    
    local i=1
    for bridge_info in "${RTP_BRIDGES[@]}"; do
        bridge_desc="${bridge_info##*:}"
        echo "  $i) $bridge_desc"
        ((i++))
    done
    
    echo ""
    echo "UDP Bridge:"
    echo "  $i) ${UDP_BRIDGE##*:}"
    
    echo ""
    echo "Management:"
    echo "  s) Show status"
    echo "  x) Stop all bridges"
    echo "  q) Quit"
    echo ""
}

# Main menu loop
main() {
    while true; do
        show_menu
        read -p "Choose option: " choice
        
        case $choice in
            1)
                start_bridge "rtp-bridge-manual.sh" "Manual RTP Bridge"
                ;;
            2)
                start_bridge "rew-rtp-bridge.sh" "REW-Specific RTP Bridge"
                ;;
            3)
                start_bridge "rew-rtp-robust.sh" "Ultra-Robust RTP Bridge"
                ;;
            4)
                start_bridge "rtp-to-alsa.sh" "Standard RTP Bridge"
                ;;
            5)
                start_bridge "udp-to-alsa.sh" "UDP Bridge"
                ;;
            s|S)
                show_status
                read -p "Press Enter to continue..."
                ;;
            x|X)
                stop_all
                read -p "Press Enter to continue..."
                ;;
            q|Q)
                log "👋 Bridge Manager exiting..."
                exit 0
                ;;
            *)
                warning "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Handle command line arguments
case "${1:-}" in
    status)
        show_status
        ;;
    stop)
        stop_all
        ;;
    start-rew)
        start_bridge "rew-rtp-bridge.sh" "REW-Specific RTP Bridge"
        ;;
    start-robust)
        start_bridge "rew-rtp-robust.sh" "Ultra-Robust RTP Bridge"
        ;;
    start-manual)
        start_bridge "rtp-bridge-manual.sh" "Manual RTP Bridge"
        ;;
    start-udp)
        start_bridge "udp-to-alsa.sh" "UDP Bridge"
        ;;
    *)
        main
        ;;
esac
