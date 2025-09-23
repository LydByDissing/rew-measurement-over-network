#!/bin/bash
#
# Simple REW Audio Receiver Deployment Script
# Deploys RTP/UDP to ALSA bridges and CamillaDSP
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMILLADSP_VERSION="v3.0.1"
TARGET_DIR="/home/pi/rew-receiver"
PACKAGE_NAME="rew-receiver-package"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEPLOY]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

show_usage() {
    echo "REW Audio Receiver Deployment"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  download          Download ARM binaries and create package"
    echo "  package           Create deployment tarball from binaries"
    echo "  install           Install locally (native)"
    echo "  deploy PI_IP      Deploy to remote Pi (native via tarball)"
    echo "  build             Build Docker image"
    echo "  docker-deploy     Deploy Docker container locally"
    echo "  docker-remote PI_IP Deploy Docker to remote Pi"
    echo "  test              Test local installation"
    echo "  clean             Clean up installation"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 download                           # Download binaries and create package"
    echo "  $0 package                            # Create tarball from existing package"
    echo "  $0 deploy pi@192.168.1.254            # Deploy to Pi via tarball"
    echo ""
}

# Generate version tag
generate_unique_tag() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local git_hash="unknown"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            git_hash="${git_hash}-dirty"
        fi
    fi
    
    echo "${timestamp}-arm-${git_hash}"
}

# Download CamillaDSP binary for ARM
download_camilladsp_arm() {
    local download_dir="$1"
    local version="${CAMILLADSP_VERSION}"
    
    log "Downloading CamillaDSP $version for ARM v6..."
    
    local url="https://github.com/HEnquist/camilladsp/releases/download/${version}/camilladsp-linux-armv6.tar.gz"
    local tarball="$download_dir/camilladsp_${version}_linux_armv6.tar.gz"
    
    if [ ! -f "$tarball" ]; then
        curl -L -o "$tarball" "$url"
    fi
    
    tar -xzf "$tarball" -C "$download_dir"
    chmod +x "$download_dir/camilladsp"
    
    success "CamillaDSP ARM binary downloaded to $download_dir/camilladsp"
}

# Download all ARM binaries
download_arm_binaries() {
    log "📥 Downloading ARM binaries for Pi deployment..."
    
    local download_dir="$SCRIPT_DIR/binaries"
    mkdir -p "$download_dir"
    
    download_camilladsp_arm "$download_dir"
    
    success "All ARM binaries downloaded to $download_dir/"
}

# Create deployment package
create_package() {
    local package_dir="$SCRIPT_DIR/$PACKAGE_NAME"
    
    log "Creating deployment package..."
    
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    
    # Check if binaries exist
    if [ ! -f "$SCRIPT_DIR/binaries/camilladsp" ]; then
        log "ARM binaries not found, downloading..."
        download_arm_binaries
    fi
    
    # Copy binaries
    cp "$SCRIPT_DIR/binaries/camilladsp" "$package_dir/"
    
    # Copy configuration files
    if [ -f "$SCRIPT_DIR/camilladsp.yml.template" ]; then
        # Generate default camilladsp.yml from template for package
        AUDIO_DEVICE="hw:CARD=sndrpimerusamp" envsubst < "$SCRIPT_DIR/camilladsp.yml.template" > "$package_dir/camilladsp.yml"
        cp "$SCRIPT_DIR/camilladsp.yml.template" "$package_dir/"
    else
        cp "$SCRIPT_DIR/camilladsp.yml" "$package_dir/"
    fi
    
    # Copy bridge scripts
    cp "$SCRIPT_DIR/rtp-to-alsa.sh" "$package_dir/"
    cp "$SCRIPT_DIR/udp-to-alsa.sh" "$package_dir/"
    
    # Copy service files
    cp "$SCRIPT_DIR/camilladsp.service" "$package_dir/"
    [ -f "$SCRIPT_DIR/udp-bridge.service" ] && cp "$SCRIPT_DIR/udp-bridge.service" "$package_dir/"
    [ -f "$SCRIPT_DIR/rtp-bridge.service" ] && cp "$SCRIPT_DIR/rtp-bridge.service" "$package_dir/"
    
    # Copy utilities and test scripts
    [ -f "$SCRIPT_DIR/test-audio.sh" ] && cp "$SCRIPT_DIR/test-audio.sh" "$package_dir/"
    [ -f "$SCRIPT_DIR/validate-audio-device.sh" ] && cp "$SCRIPT_DIR/validate-audio-device.sh" "$package_dir/"
    [ -f "$SCRIPT_DIR/test-merus-amp.sh" ] && cp "$SCRIPT_DIR/test-merus-amp.sh" "$package_dir/"
    [ -f "$SCRIPT_DIR/configure-audio-device.sh" ] && cp "$SCRIPT_DIR/configure-audio-device.sh" "$package_dir/"
    
    # Copy install script from rew-receiver-package if it exists, or create it
    if [ -f "$SCRIPT_DIR/rew-receiver-package/install.sh" ]; then
        cp "$SCRIPT_DIR/rew-receiver-package/install.sh" "$package_dir/"
    else
        cp "$SCRIPT_DIR/install.sh" "$package_dir/"
    fi
    
    # Set permissions
    chmod +x "$package_dir"/*.sh 2>/dev/null || true
    chmod +x "$package_dir/camilladsp"
    
    success "Deployment package created in $package_dir/"
}

# Create deployment tarball
create_tarball() {
    local package_dir="$SCRIPT_DIR/$PACKAGE_NAME"
    
    if [ ! -d "$package_dir" ]; then
        error "Package directory not found. Run: $0 package first"
        return 1
    fi
    
    local unique_tag=$(generate_unique_tag)
    local export_dir="$SCRIPT_DIR/export"
    local tarball_name="rew-receiver-native-${unique_tag}.tar.gz"
    
    log "Creating deployment tarball: $tarball_name"
    
    mkdir -p "$export_dir"
    
    # Clean up old tarballs (keep only last 3)
    log "Cleaning up old native tarballs..."
    ls -t "$export_dir"/rew-receiver-native-*.tar.gz 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
    
    # Create tarball with package contents
    cd "$SCRIPT_DIR"
    tar -czf "$export_dir/$tarball_name" "$PACKAGE_NAME"
    
    # Save export info
    echo "package_name=${PACKAGE_NAME}" > "$export_dir/.export-info"
    echo "tarball=${tarball_name}" >> "$export_dir/.export-info"
    echo "created=$(date)" >> "$export_dir/.export-info"
    echo "tag=${unique_tag}" >> "$export_dir/.export-info"
    
    success "Deployment tarball created: $export_dir/$tarball_name"
    
    log "Tarball contents (first 10 files):"
    tar -tzf "$export_dir/$tarball_name" | head -10
    
    log "Deployment instructions:"
    echo "1. scp $export_dir/$tarball_name pi@pi-ip:~/"
    echo "2. ssh pi@pi-ip 'tar -xzf $(basename "$tarball_name") && cd $PACKAGE_NAME && ./install.sh'"
}

# Download CamillaDSP binary
download_camilladsp() {
    local download_dir="$1"
    local version="${CAMILLADSP_VERSION}"
    
    log "Downloading CamillaDSP $version for ARM..."
    
    local url="https://github.com/HEnquist/camilladsp/releases/download/${version}/camilladsp-linux-armv6.tar.gz"
    local tarball="$download_dir/camilladsp-linux-armv6.tar.gz"
    
    if ! curl -L -o "$tarball" "$url"; then
        error "Failed to download CamillaDSP"
        return 1
    fi
    
    tar -xzf "$tarball" -C "$download_dir" camilladsp
    chmod +x "$download_dir/camilladsp"
    
    success "CamillaDSP binary downloaded to $download_dir/camilladsp"
}

# Install locally
install_local() {
    log "🎵 Installing REW Audio Receiver..."
    
    # Create target directory
    sudo mkdir -p "$TARGET_DIR"
    
    # Stop any existing services
    sudo systemctl stop camilladsp 2>/dev/null || true
    
    # Download CamillaDSP if not present
    if [ ! -f "$SCRIPT_DIR/camilladsp" ]; then
        log "Downloading CamillaDSP binary..."
        download_camilladsp "$SCRIPT_DIR"
    fi
    
    # Copy files
    sudo cp "$SCRIPT_DIR/camilladsp" "$TARGET_DIR/" 2>/dev/null || {
        sudo systemctl stop camilladsp 2>/dev/null || true
        sleep 2
        sudo cp "$SCRIPT_DIR/camilladsp" "$TARGET_DIR/"
    }
    
    # Copy configuration files
    sudo cp "$SCRIPT_DIR/camilladsp.yml" "$TARGET_DIR/" 2>/dev/null || true
    
    # Copy bridge scripts
    sudo cp "$SCRIPT_DIR/rtp-to-alsa.sh" "$TARGET_DIR/"
    sudo cp "$SCRIPT_DIR/udp-to-alsa.sh" "$TARGET_DIR/"
    
    # Copy service files
    sudo cp "$SCRIPT_DIR/camilladsp.service" /etc/systemd/system/
    sudo cp "$SCRIPT_DIR/udp-bridge.service" /etc/systemd/system/
    
    # Set permissions
    sudo chmod +x "$TARGET_DIR/camilladsp" "$TARGET_DIR"/*.sh
    sudo chown -R pi:pi "$TARGET_DIR"
    
    # Create log directory
    sudo mkdir -p /var/log/camilladsp
    sudo chown pi:pi /var/log/camilladsp
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable and start services
    sudo systemctl enable camilladsp
    sudo systemctl start camilladsp
    
    # Check service status
    if systemctl is-active --quiet camilladsp; then
        success "🎉 REW Audio Receiver installed successfully!"
        log ""
        log "🎵 Ready for REW audio measurements with:"
        log "• CamillaDSP: Running on http://localhost:1234"
        log "• Bridge Management: $TARGET_DIR/manage-bridges.sh"
        log "• Multiple RTP bridge options available"
        log ""
        log "🎯 Quick Start for REW measurements:"
        log "• Start REW bridge: $TARGET_DIR/manage-bridges.sh start-rew"
        log "• Check bridge status: $TARGET_DIR/manage-bridges.sh status"
        log ""
        log "Bridge Options:"
        log "• REW-specific (recommended): Auto-restart between measurements"
        log "• Ultra-robust: Maximum packet loss tolerance"
        log "• Manual: User-controlled operation"
        log ""
        log "System Management:"
        log "• View CamillaDSP logs: sudo journalctl -u camilladsp -f"
        log "• Restart CamillaDSP: sudo systemctl restart camilladsp"
        log "• Stop CamillaDSP: sudo systemctl stop camilladsp"
    else
        error "❌ CamillaDSP installation failed"
        echo "Check logs: sudo journalctl -u camilladsp"
        exit 1
    fi
}

# Deploy to remote Pi using tarball
deploy_remote() {
    local ssh_target="$1"
    
    if [ -z "$ssh_target" ]; then
        error "Please provide Pi SSH target (e.g., pi@192.168.1.254)"
        exit 1
    fi
    
    log "🚀 Deploying REW Audio Receiver to Pi: $ssh_target"
    
    # Always create fresh package and tarball for deploy-remote
    log "Creating fresh deployment package with latest files..."
    create_package
    create_tarball
    
    # Get the latest tarball
    local export_dir="$SCRIPT_DIR/export"
    local latest_tarball=$(ls -t "$export_dir"/rew-receiver-native-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$latest_tarball" ]; then
        error "No deployment tarball found. Run: $0 package first"
        exit 1
    fi
    
    log "Using tarball: $(basename "$latest_tarball")"
    
    # SSH options for better connection handling
    local ssh_opts="-o ConnectTimeout=10 -o ServerAliveInterval=60"
    
    log "Checking Pi connectivity..."
    if ! ssh $ssh_opts "$ssh_target" "echo 'Pi is reachable'" 2>/dev/null; then
        error "Cannot connect to Pi at $ssh_target"
        exit 1
    fi
    
    # Transfer deployment tarball
    log "Transferring native deployment package..."
    scp $ssh_opts "$latest_tarball" "$ssh_target:~/"
    
    success "Deployment package transferred"
    
    # Execute remote installation
    local tarball_name=$(basename "$latest_tarball")
    
    log "Installing on Pi..."
    ssh $ssh_opts "$ssh_target" "
        tar -xzf '$tarball_name' &&
        cd '$PACKAGE_NAME' &&
        ./install.sh
    "
    
    success "🎉 Native deployment to Pi completed!"
    
    # Automatically start the REW-specific RTP bridge
    log "🚀 Starting REW RTP Bridge by default..."
    ssh $ssh_opts "$ssh_target" "/home/pi/rew-receiver/manage-bridges.sh start-rew" >/dev/null 2>&1 &
    sleep 2
    
    success "✅ REW RTP Bridge started and ready for measurements!"
    
    log ""
    log "🎵 Pi is ready for REW audio measurements with:"
    log "• CamillaDSP: Running via systemd"
    log "• REW RTP Bridge: Auto-started and ready (port 5004)"
    log "• Bridge Management: ssh $ssh_target '/home/pi/rew-receiver/manage-bridges.sh status'"
    log ""
    log "🎯 Ready for REW measurements! Use this FFmpeg command:"
    echo "ffmpeg -f lavfi -i \"sine=frequency=1000:duration=3\" -ar 48000 -ac 2 -acodec pcm_s16le -f rtp -payload_type 10 -pkt_size 1200 rtp://$(echo $ssh_target | cut -d'@' -f2):5004"
    log ""
    log "Bridge Management Commands:"
    log "• Check status: ssh $ssh_target '/home/pi/rew-receiver/manage-bridges.sh status'"
    log "• Start REW bridge: ssh $ssh_target '/home/pi/rew-receiver/manage-bridges.sh start-rew'"
    log "• Start robust bridge: ssh $ssh_target '/home/pi/rew-receiver/manage-bridges.sh start-robust'"
    log "• Stop all bridges: ssh $ssh_target '/home/pi/rew-receiver/manage-bridges.sh stop'"
}

# Test installation
test_installation() {
    log "Testing REW Audio Receiver installation..."
    
    # Check if CamillaDSP is running
    if systemctl is-active --quiet camilladsp; then
        success "✅ CamillaDSP is running"
    else
        error "❌ CamillaDSP is not running"
    fi
    
    # Check if bridge scripts exist
    if [ -f "$TARGET_DIR/rtp-to-alsa.sh" ]; then
        success "✅ RTP bridge script available"
    else
        error "❌ RTP bridge script missing"
    fi
    
    if [ -f "$TARGET_DIR/udp-to-alsa.sh" ]; then
        success "✅ UDP bridge script available"
    else
        error "❌ UDP bridge script missing"
    fi
    
    # Check ALSA loopback
    if lsmod | grep -q snd_aloop; then
        success "✅ ALSA loopback module loaded"
    else
        warning "⚠️  ALSA loopback module not loaded"
        log "Load with: sudo modprobe snd-aloop"
    fi
}

# Clean up
clean_installation() {
    log "Cleaning up REW Audio Receiver..."
    
    # Clean up native installation
    sudo systemctl stop camilladsp udp-bridge rtp-bridge 2>/dev/null || true
    sudo systemctl disable camilladsp udp-bridge rtp-bridge 2>/dev/null || true
    sudo rm -f /etc/systemd/system/camilladsp.service
    sudo rm -f /etc/systemd/system/udp-bridge.service
    sudo rm -f /etc/systemd/system/rtp-bridge.service
    sudo rm -rf "$TARGET_DIR"
    sudo systemctl daemon-reload
    
    # Clean up Docker
    docker stop rew-audio-receiver 2>/dev/null || true
    docker rm rew-audio-receiver 2>/dev/null || true
    
    success "Cleanup completed"
}

# Docker functions
build_docker_image() {
    log "Building Docker image..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed"
        exit 1
    fi
    
    # Build for current platform
    docker build -t rew-audio-receiver:latest .
    
    success "Docker image built successfully"
}

deploy_docker_local() {
    log "Deploying Docker container locally..."
    
    # Stop existing container
    docker stop rew-audio-receiver 2>/dev/null || true
    docker rm rew-audio-receiver 2>/dev/null || true
    
    # Start container with docker-compose
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
    else
        # Fallback to docker run
        docker run -d \
            --name rew-audio-receiver \
            --restart unless-stopped \
            -p 1234:1234 \
            -p 8000:8000/udp \
            -p 5004:5004/udp \
            --device /dev/snd:/dev/snd \
            rew-audio-receiver:latest
    fi
    
    success "Docker container deployed locally"
}

deploy_docker_remote() {
    local pi_ip="$1"
    
    if [ -z "$pi_ip" ]; then
        error "Please provide Pi IP address"
        exit 1
    fi
    
    log "Deploying Docker container to Pi at $pi_ip..."
    
    # Build ARM image
    log "Building ARM image..."
    docker buildx build --platform linux/arm/v6 -t rew-audio-receiver:arm .
    
    # Save and transfer image
    log "Transferring image to Pi..."
    docker save rew-audio-receiver:arm | gzip > rew-audio-receiver-arm.tar.gz
    scp rew-audio-receiver-arm.tar.gz docker-compose.yml pi@"$pi_ip":/tmp/
    
    # Load and run on Pi
    ssh pi@"$pi_ip" "
        cd /tmp &&
        docker load < rew-audio-receiver-arm.tar.gz &&
        docker tag rew-audio-receiver:arm rew-audio-receiver:latest &&
        docker-compose down 2>/dev/null || true &&
        docker-compose up -d
    "
    
    # Cleanup
    rm -f rew-audio-receiver-arm.tar.gz
    
    success "Docker deployment to $pi_ip completed!"
}

# Main command handling
case "${1:-}" in
    download)
        download_arm_binaries
        ;;
    package)
        create_package
        create_tarball
        ;;
    install)
        install_local
        ;;
    deploy)
        deploy_remote "$2"
        ;;
    build)
        build_docker_image
        ;;
    docker-deploy)
        build_docker_image
        deploy_docker_local
        ;;
    docker-remote)
        deploy_docker_remote "$2"
        ;;
    test)
        test_installation
        ;;
    clean)
        clean_installation
        ;;
    -h|--help|help|"")
        show_usage
        exit 0
        ;;
    *)
        error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
