#!/bin/bash
#
# REW MediaMTX Audio Receiver - Deployment Script
# Deploys MediaMTX + CamillaDSP native binaries to Raspberry Pi
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/home/pi/rew-receiver"
MEDIAMTX_VERSION="v1.12.3"
CAMILLADSP_VERSION="v2.0.3"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEPLOY]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Show usage
show_usage() {
    cat << EOF
REW MediaMTX Audio Receiver - Deployment Script

Usage: $0 [OPTIONS] COMMAND

Commands:
    download            Download ARM v6 binaries locally
    deploy-remote HOST  Deploy to remote Pi via SSH
    install-local       Install on local Pi (run on Pi)
    start               Start services
    stop                Stop services
    status              Show service status
    logs                Show service logs
    clean               Remove installation
    
Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --mediamtx-version  MediaMTX version (default: $MEDIAMTX_VERSION)
    --camilladsp-version CamillaDSP version (default: $CAMILLADSP_VERSION)

Examples:
    $0 download                           # Download binaries locally
    $0 deploy-remote pi@192.168.1.100     # Deploy to remote Pi
    $0 status                             # Check service status
    $0 logs                               # View service logs

Environment:
    Set MEDIAMTX_VERSION and CAMILLADSP_VERSION to override versions.
EOF
}

# Download MediaMTX ARM v6 binary
download_mediamtx() {
    local version="$1"
    local download_dir="$SCRIPT_DIR/binaries"
    
    mkdir -p "$download_dir"
    
    log "Downloading MediaMTX $version for ARM v6..."
    
    local url="https://github.com/bluenviron/mediamtx/releases/download/${version}/mediamtx_${version}_linux_armv6.tar.gz"
    local tarball="$download_dir/mediamtx_${version}_linux_armv6.tar.gz"
    
    if [ ! -f "$tarball" ]; then
        curl -L -o "$tarball" "$url"
    fi
    
    # Extract binary
    tar -xzf "$tarball" -C "$download_dir" mediamtx
    chmod +x "$download_dir/mediamtx"
    
    success "MediaMTX binary downloaded to $download_dir/mediamtx"
}

# Download CamillaDSP ARM v6 binary
download_camilladsp() {
    local version="$1"
    local download_dir="$SCRIPT_DIR/binaries"
    
    mkdir -p "$download_dir"
    
    log "Downloading CamillaDSP $version for ARM v6..."
    
    local url="https://github.com/HEnquist/camilladsp/releases/download/${version}/camilladsp-linux-armv6.tar.gz"
    local tarball="$download_dir/camilladsp_${version}_linux_armv6.tar.gz"
    
    if [ ! -f "$tarball" ]; then
        curl -L -o "$tarball" "$url"
    fi
    
    # Extract binary
    tar -xzf "$tarball" -C "$download_dir"
    chmod +x "$download_dir/camilladsp"
    
    success "CamillaDSP binary downloaded to $download_dir/camilladsp"
}

# Create deployment package
create_package() {
    local package_dir="$SCRIPT_DIR/rew-receiver-package"
    
    log "Creating deployment package..."
    
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    
    # Copy binaries
    cp "$SCRIPT_DIR/binaries/mediamtx" "$package_dir/"
    cp "$SCRIPT_DIR/binaries/camilladsp" "$package_dir/"
    
    # Copy configurations
    cp "$SCRIPT_DIR/mediamtx.yml" "$package_dir/"
    cp "$SCRIPT_DIR/camilladsp.yml" "$package_dir/"
    
    # Copy systemd services
    cp "$SCRIPT_DIR/mediamtx.service" "$package_dir/"
    cp "$SCRIPT_DIR/camilladsp.service" "$package_dir/"
    
    # Create installation script
    cat > "$package_dir/install.sh" << 'INSTALL_EOF'
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

TARGET_DIR="/home/pi/rew-receiver"
CURRENT_DIR="$(pwd)"

log "🎵 Installing REW MediaMTX Audio Receiver..."

# Create target directory
sudo mkdir -p "$TARGET_DIR"
sudo chown pi:pi "$TARGET_DIR"

# Copy files
log "Installing binaries and configurations..."
cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/"
chmod +x "$TARGET_DIR/mediamtx" "$TARGET_DIR/camilladsp"

# Install systemd services
log "Installing systemd services..."
sudo cp mediamtx.service camilladsp.service /etc/systemd/system/
sudo systemctl daemon-reload

# Setup ALSA loopback
log "Configuring ALSA loopback device..."
sudo modprobe snd-aloop || true
echo "snd-aloop" | sudo tee -a /etc/modules-load.d/modules.conf > /dev/null || true

# Create log directories
sudo mkdir -p /var/log/mediamtx
sudo chown pi:pi /var/log/mediamtx

# Stop any existing services
sudo systemctl stop mediamtx camilladsp 2>/dev/null || true

# Enable and start services
log "Starting services..."
sudo systemctl enable mediamtx camilladsp
sudo systemctl start mediamtx
sleep 2
sudo systemctl start camilladsp

# Check status
if systemctl is-active --quiet mediamtx && systemctl is-active --quiet camilladsp; then
    success "🎉 REW MediaMTX Audio Receiver installed successfully!"
    echo
    echo "📊 Service Status:"
    sudo systemctl status mediamtx --no-pager -l
    sudo systemctl status camilladsp --no-pager -l
    echo
    echo "🔗 Access Points:"
    echo "• MediaMTX API: http://$(hostname -I | awk '{print $1}'):9997"
    echo "• CamillaDSP API: http://$(hostname -I | awk '{print $1}'):1234"
    echo "• RTSP Stream: rtsp://$(hostname -I | awk '{print $1}'):8554/rew_audio"
    echo "• RTP Input: rtp://$(hostname -I | awk '{print $1}'):5004"
    echo
    echo "🔧 Commands:"
    echo "• View logs: sudo journalctl -u mediamtx -u camilladsp -f"
    echo "• Restart: sudo systemctl restart mediamtx camilladsp"
    echo "• Stop: sudo systemctl stop mediamtx camilladsp"
else
    error "❌ Service installation failed"
    echo "Check logs: sudo journalctl -u mediamtx -u camilladsp"
    exit 1
fi
INSTALL_EOF
    
    chmod +x "$package_dir/install.sh"
    
    success "Deployment package created in $package_dir/"
}

# Deploy to remote Pi
deploy_remote() {
    local ssh_target="$1"
    
    if [ -z "$ssh_target" ]; then
        error "SSH target not specified"
        echo "Usage: $0 deploy-remote user@hostname"
        exit 1
    fi
    
    log "Deploying MediaMTX + CamillaDSP to remote Pi: $ssh_target"
    
    # Check if package exists
    local package_dir="$SCRIPT_DIR/rew-receiver-package"
    if [ ! -d "$package_dir" ]; then
        error "Deployment package not found. Run: $0 download first"
        exit 1
    fi
    
    # SSH options
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no"
    
    # Test SSH connectivity
    log "Testing SSH connectivity..."
    if ssh $ssh_opts "$ssh_target" "echo 'SSH test successful'"; then
        success "SSH connectivity verified"
    else
        error "SSH connection failed to $ssh_target"
        exit 1
    fi
    
    # Transfer package
    log "Transferring deployment package..."
    scp $ssh_opts -r "$package_dir" "$ssh_target":~/rew-deployment/
    
    # Run installation
    log "Installing on remote Pi..."
    ssh $ssh_opts "$ssh_target" "cd ~/rew-deployment && ./install.sh"
    
    success "🎉 Deployment completed!"
    echo
    echo "🔗 Next Steps:"
    echo "1. Test RTP stream: Send audio to rtp://$(echo $ssh_target | cut -d@ -f2):5004"
    echo "2. Check status: ssh $ssh_target 'sudo systemctl status mediamtx camilladsp'"
    echo "3. View logs: ssh $ssh_target 'sudo journalctl -u mediamtx -u camilladsp -f'"
}

# Main script logic
main() {
    local command=""
    local ssh_target=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --mediamtx-version)
                MEDIAMTX_VERSION="$2"
                shift 2
                ;;
            --camilladsp-version)
                CAMILLADSP_VERSION="$2"
                shift 2
                ;;
            download|deploy-remote|install-local|start|stop|status|logs|clean)
                command="$1"
                shift
                ;;
            *)
                if [ "$command" = "deploy-remote" ] && [ -z "$ssh_target" ]; then
                    ssh_target="$1"
                    shift
                else
                    error "Unknown argument: $1"
                    show_usage
                    exit 1
                fi
                ;;
        esac
    done
    
    if [ -z "$command" ]; then
        show_usage
        exit 1
    fi
    
    # Execute command
    case $command in
        download)
            download_mediamtx "$MEDIAMTX_VERSION"
            download_camilladsp "$CAMILLADSP_VERSION"
            create_package
            ;;
        deploy-remote)
            deploy_remote "$ssh_target"
            ;;
        install-local)
            if [ ! -f "./install.sh" ]; then
                error "install.sh not found. Run this command from the deployment package directory."
                exit 1
            fi
            ./install.sh
            ;;
        start)
            sudo systemctl start mediamtx camilladsp
            success "Services started"
            ;;
        stop)
            sudo systemctl stop mediamtx camilladsp
            success "Services stopped"
            ;;
        status)
            sudo systemctl status mediamtx camilladsp --no-pager
            ;;
        logs)
            sudo journalctl -u mediamtx -u camilladsp -f
            ;;
        clean)
            sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
            sudo systemctl disable mediamtx camilladsp 2>/dev/null || true
            sudo rm -f /etc/systemd/system/mediamtx.service /etc/systemd/system/camilladsp.service
            sudo systemctl daemon-reload
            sudo rm -rf "$TARGET_DIR"
            success "Installation cleaned"
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not installed"
    exit 1
fi

# Run main function
main "$@"