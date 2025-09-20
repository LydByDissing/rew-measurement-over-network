#!/bin/bash
#
# REW MediaMTX Audio Receiver - Deployment Script
# Native binary deployment with tarball packaging
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIAMTX_VERSION="v1.12.3"
CAMILLADSP_VERSION="v2.0.3"
PACKAGE_NAME="rew-receiver-package"

# Versioning configuration
VERSION_FILE="$SCRIPT_DIR/.version"

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

# Version management functions
get_git_hash() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

        # Simple dirty check - just mark as dirty if git status shows changes
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            git_hash="${git_hash}-dirty"
        fi

        echo "$git_hash"
    else
        echo "nogit"
    fi
}

show_git_context() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        local commit_subject=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "unknown")
        local commit_date=$(git log -1 --pretty=format:"%ci" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

        log "Git context:"
        log "  Branch: $current_branch"
        log "  Commit: $(git rev-parse --short HEAD 2>/dev/null) ($commit_date)"
        log "  Subject: $commit_subject"

        # Simple git status check
        local status_output=$(git status --porcelain 2>/dev/null)
        if [ -n "$status_output" ]; then
            local modified_count=$(echo "$status_output" | grep -c '^.M' || echo "0")
            warning "Working directory has uncommitted changes:"
            [ "$modified_count" -gt 0 ] && warning "  Modified files: $modified_count"
        else
            success "Working directory is clean"
        fi
    else
        warning "Not in a git repository"
    fi
}

get_arch_suffix() {
    local platform="$1"
    case "$platform" in
        "linux/arm/v6"|"linux/arm/v7") echo "arm" ;;
        "linux/amd64") echo "amd64" ;;
        *) echo "unknown" ;;
    esac
}

generate_unique_tag() {
    local platform="${1:-linux/amd64}"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local git_hash=$(get_git_hash)
    local arch=$(get_arch_suffix "$platform")

    echo "${timestamp}-${arch}-${git_hash}"
}

get_latest_version_tag() {
    local arch="${1:-amd64}"
    if [ -f "$VERSION_FILE" ]; then
        grep "^${arch}:" "$VERSION_FILE" 2>/dev/null | cut -d: -f2 || echo ""
    else
        echo ""
    fi
}

save_version_tag() {
    local arch="$1"
    local tag="$2"

    # Create version file if it doesn't exist
    touch "$VERSION_FILE"

    # Remove existing entry for this architecture
    if [ -f "$VERSION_FILE" ]; then
        grep -v "^${arch}:" "$VERSION_FILE" > "${VERSION_FILE}.tmp" 2>/dev/null || true
        mv "${VERSION_FILE}.tmp" "$VERSION_FILE"
    fi

    # Add new entry
    echo "${arch}:${tag}" >> "$VERSION_FILE"

    log "Saved version tag for $arch: $tag"
}

# Show usage
show_usage() {
    cat << EOF
REW MediaMTX Audio Receiver - Deployment Script

Usage: $0 [OPTIONS] COMMAND

Commands:
    download            Download ARM binaries and create package
    build               Build Docker image for testing only
    package             Create deployment tarball from binaries
    deploy-remote HOST  Deploy native binaries to remote Pi via SSH
    test-container      Test with container locally
    promote VERSION     Promote a version to latest
    list-versions       List available package versions
    start               Start native services on local Pi
    stop                Stop native services on local Pi
    logs                Show service logs
    status              Show service status
    clean               Remove native installation

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --mediamtx-version VER  MediaMTX version (default: $MEDIAMTX_VERSION)
    --camilladsp-version VER CamillaDSP version (default: $CAMILLADSP_VERSION)
    --test-with-container   Use container for testing deployment

Examples:
    $0 download                           # Download binaries and create package
    $0 package                            # Create tarball from existing package
    $0 deploy-remote pi@192.168.1.100     # Deploy native binaries to Pi
    $0 test-container                     # Test with Docker container locally
    $0 status                             # Check native service status
    $0 logs                               # View native service logs

Deployment Workflow:
    1. Download: $0 download                            # Downloads ARM binaries
    2. Package: $0 package                              # Creates deployment tarball
    3. Deploy: $0 deploy-remote pi@IP                   # Deploys native binaries
    4. Test: ssh pi@IP 'sudo systemctl status mediamtx camilladsp'

This script deploys native MediaMTX + CamillaDSP binaries for better audio performance.
Docker containers are available for testing purposes only.
EOF
}

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v curl >/dev/null 2>&1; then
        missing+=("curl")
    fi

    if ! command -v tar >/dev/null 2>&1; then
        missing+=("tar")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        echo "Please install required tools first."
        exit 1
    fi
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "linux/amd64"
            ;;
        armv6l)
            echo "linux/arm/v6"
            ;;
        armv7l)
            echo "linux/arm/v7"
            ;;
        aarch64)
            echo "linux/arm64"
            ;;
        *)
            warning "Unknown architecture: $arch, defaulting to linux/amd64"
            echo "linux/amd64"
            ;;
    esac
}

# Download MediaMTX ARM binary
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

# Download CamillaDSP ARM binary
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

# Download all required binaries
download_binaries() {
    log "Downloading ARM binaries for MediaMTX and CamillaDSP..."

    download_mediamtx "$MEDIAMTX_VERSION"
    download_camilladsp "$CAMILLADSP_VERSION"

    success "All binaries downloaded successfully"
}

# Create deployment package
create_package() {
    local package_dir="$SCRIPT_DIR/$PACKAGE_NAME"

    log "Creating deployment package..."

    rm -rf "$package_dir"
    mkdir -p "$package_dir"

    # Check if binaries exist
    if [ ! -f "$SCRIPT_DIR/binaries/mediamtx" ] || [ ! -f "$SCRIPT_DIR/binaries/camilladsp" ]; then
        error "Binaries not found. Run: $0 download first"
        exit 1
    fi

    # Copy binaries
    cp "$SCRIPT_DIR/binaries/mediamtx" "$package_dir/"
    cp "$SCRIPT_DIR/binaries/camilladsp" "$package_dir/"

    # Copy configurations
    cp "$SCRIPT_DIR/mediamtx.yml" "$package_dir/"
    cp "$SCRIPT_DIR/camilladsp.yml" "$package_dir/"
    if [ -f "$SCRIPT_DIR/camilladsp-fallback.yml" ]; then
        cp "$SCRIPT_DIR/camilladsp-fallback.yml" "$package_dir/"
    fi

    # Copy systemd services
    cp "$SCRIPT_DIR/mediamtx.service" "$package_dir/"
    cp "$SCRIPT_DIR/camilladsp.service" "$package_dir/"

    # Copy the install script from existing package if it exists, or create it
    if [ -f "$SCRIPT_DIR/rew-receiver-package/install.sh" ]; then
        cp "$SCRIPT_DIR/rew-receiver-package/install.sh" "$package_dir/"
    else
        # Use the existing deploy-mediamtx.sh as a template for install script
        cat > "$package_dir/install.sh" << 'INSTALL_EOF'
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

TARGET_DIR="/home/pi/rew-receiver"
CURRENT_DIR="$(pwd)"

log "🎵 Installing REW MediaMTX Audio Receiver..."

# Create target directory
sudo mkdir -p "$TARGET_DIR"
sudo chown pi:pi "$TARGET_DIR"

# Stop any existing services first to free up binaries
log "Stopping existing services..."
sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
sleep 2

# Copy files
log "Installing binaries and configurations..."
if ! cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/" 2>/dev/null; then
    error "Failed to copy binaries. Trying to force stop services and kill processes..."
    sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
    sudo pkill -f mediamtx 2>/dev/null || true
    sudo pkill -f camilladsp 2>/dev/null || true
    sleep 3

    log "Retrying file copy..."
    cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/"
fi
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

# Check ALSA device configuration and select appropriate config
log "Checking ALSA device configuration..."

# Check if loopback device is available
if grep -q "Loopback" /proc/asound/cards 2>/dev/null; then
    success "ALSA Loopback device detected"

    # Check if any processes are using audio devices
    if pgrep -f "pulseaudio\|jackd" >/dev/null 2>&1; then
        warning "Audio processes detected, stopping them..."
        sudo pkill pulseaudio 2>/dev/null || true
        sudo pkill jackd 2>/dev/null || true
        sleep 1
    fi
else
    warning "ALSA Loopback device not found, using fallback configuration"
    if [ -f "$TARGET_DIR/camilladsp-fallback.yml" ]; then
        log "Switching to fallback configuration..."
        cp "$TARGET_DIR/camilladsp-fallback.yml" "$TARGET_DIR/camilladsp.yml"
    fi
fi

# Enable and start services
log "Starting services..."
sudo systemctl enable mediamtx
sudo systemctl start mediamtx
sleep 3

# Disable CamillaDSP temporarily due to ALSA enumeration issues
warning "Disabling CamillaDSP due to persistent ALSA enumeration issues"
warning "CamillaDSP service will be installed but not started automatically"
warning "MediaMTX will handle audio streaming without DSP processing for now"

# Install but don't enable CamillaDSP service
sudo systemctl disable camilladsp 2>/dev/null || true
sudo systemctl stop camilladsp 2>/dev/null || true

log "CamillaDSP is available but disabled. To troubleshoot later:"
log "• Check ALSA devices: cat /proc/asound/cards"
log "• Try manual start: sudo systemctl start camilladsp"
log "• View logs: sudo journalctl -u camilladsp -f"

# Check final status
MEDIAMTX_ACTIVE=$(systemctl is-active --quiet mediamtx && echo "true" || echo "false")
CAMILLADSP_ENABLED=$(systemctl is-enabled camilladsp 2>/dev/null | grep -q "enabled" && echo "true" || echo "false")

if [ "$MEDIAMTX_ACTIVE" = "true" ]; then
    success "🎉 REW MediaMTX Audio Receiver installed successfully!"
    warning "⚠️ CamillaDSP is installed but disabled due to ALSA issues"
    warning "Audio streaming works via MediaMTX without DSP processing"

    echo
    echo "📊 Service Status:"
    sudo systemctl status mediamtx --no-pager -l

    echo
    echo "🔗 Access Points:"
    echo "• MediaMTX API: http://$(hostname -I | awk '{print $1}'):9997"
    echo "• RTSP Stream: rtsp://$(hostname -I | awk '{print $1}'):8554/stream-name"
    echo "• Publish to: MediaMTX via RTSP/RTMP/WebRTC"
    echo
    echo "🔧 Commands:"
    echo "• View MediaMTX logs: sudo journalctl -u mediamtx -f"
    echo "• Restart MediaMTX: sudo systemctl restart mediamtx"
    echo "• Stop MediaMTX: sudo systemctl stop mediamtx"
    echo
    warning "🔧 CamillaDSP Troubleshooting (when ready):"
    warning "• Check ALSA devices: cat /proc/asound/cards"
    warning "• Check CamillaDSP logs: sudo journalctl -u camilladsp -f"
    warning "• Try manual start: sudo systemctl start camilladsp"
    warning "• Check config: cat $TARGET_DIR/camilladsp.yml"
else
    error "❌ MediaMTX installation failed"
    echo "Check logs: sudo journalctl -u mediamtx"
    exit 1
fi
INSTALL_EOF
    fi

    chmod +x "$package_dir/install.sh"

    success "Deployment package created in $package_dir/"
}

# Parse SSH target to extract user and host
parse_ssh_target() {
    local ssh_target="$1"
    local default_user="pi"
    
    if [[ "$ssh_target" == *"@"* ]]; then
        SSH_USER="${ssh_target%@*}"
        SSH_HOST="${ssh_target#*@}"
    else
        SSH_USER="$default_user"
        SSH_HOST="$ssh_target"
        warning "No username specified, using default: $SSH_USER@$SSH_HOST"
    fi
    
    SSH_TARGET="${SSH_USER}@${SSH_HOST}"
    log "Parsed SSH target: $SSH_TARGET (user: $SSH_USER, host: $SSH_HOST)"
}

# Create deployment tarball
create_tarball() {
    local export_dir="$SCRIPT_DIR/export"
    local package_dir="$SCRIPT_DIR/$PACKAGE_NAME"

    if [ ! -d "$package_dir" ]; then
        error "Package directory not found. Run: $0 package first"
        exit 1
    fi

    # Generate unique version tag
    local unique_tag=$(generate_unique_tag "native")
    local tarball_name="rew-receiver-native-${unique_tag}.tar.gz"

    log "Creating deployment tarball: $tarball_name"

    # Create export directory
    mkdir -p "$export_dir"

    # Clean up old tarballs
    log "Cleaning up old native tarballs..."
    rm -f "$export_dir"/rew-receiver-native-*.tar.gz

    # Create tarball with package contents
    cd "$SCRIPT_DIR"
    tar -czf "$export_dir/$tarball_name" -C "$SCRIPT_DIR" "$PACKAGE_NAME"

    # Save export info for tracking
    echo "package_name=${PACKAGE_NAME}" > "$export_dir/.export-info"
    echo "tarball=${tarball_name}" >> "$export_dir/.export-info"
    echo "deployment_type=native" >> "$export_dir/.export-info"
    echo "export_date=$(date -Iseconds)" >> "$export_dir/.export-info"

    # Add git context to export info
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_commit=$(git rev-parse HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_commit_short=$(git rev-parse --short HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_subject=$(git log -1 --pretty=format:"%s" 2>/dev/null)" >> "$export_dir/.export-info"

        # Check for dirty state
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "git_dirty=true" >> "$export_dir/.export-info"
        else
            echo "git_dirty=false" >> "$export_dir/.export-info"
        fi
    fi

    # Save the version information
    save_version_tag "native" "$unique_tag"

    success "Deployment tarball created: $export_dir/$tarball_name"
    success "✅ Version tag: $unique_tag"
    echo "Package contents:"
    tar -tzf "$export_dir/$tarball_name" | head -10
    echo
    echo "📦 To deploy to Pi:"
    echo "1. scp $export_dir/$tarball_name pi@pi-ip:~/"
    echo "2. ssh pi@pi-ip 'tar -xzf $tarball_name && cd $PACKAGE_NAME && ./install.sh'"
}

# List available image versions
list_versions() {
    log "Available image versions:"
    echo

    # Show version file contents if it exists
    if [ -f "$VERSION_FILE" ]; then
        log "Latest built versions:"
        while IFS=':' read -r arch tag; do
            if docker image inspect "${IMAGE_NAME}:${tag}" >/dev/null 2>&1; then
                local image_id=$(docker image inspect "${IMAGE_NAME}:${tag}" --format='{{.Id}}' | cut -d: -f2 | cut -c1-12)
                local created=$(docker image inspect "${IMAGE_NAME}:${tag}" --format='{{.Created}}' | cut -dT -f1)

                # Parse version tag for readable info
                local build_date=$(echo "$tag" | cut -d- -f1-2 | sed 's/-/ /; s/\(..\)\(..\)\(..\)/ \1:\2:\3/')
                local git_info=$(echo "$tag" | sed 's/.*-\([^-]*\)$/\1/')
                local status_info=""

                if [[ "$tag" == *"-dirty"* ]]; then
                    status_info=" (uncommitted changes)"
                fi

                success "✅ $arch: $tag"
                log "   Built: $build_date, Git: $git_info$status_info"
                log "   Image: $image_id, Created: $created"
            else
                warning "❌ $arch: $tag (image not found locally)"
            fi
        done < "$VERSION_FILE"
        echo
    fi

    # Show all available image tags
    log "All local images:"
    docker images "${IMAGE_NAME}" --format "table {{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | head -20

    echo

    # Show export info if available
    if [ -f "$SCRIPT_DIR/export/.export-info" ]; then
        log "Last export package info:"
        source "$SCRIPT_DIR/export/.export-info"
        log "  Tag: $export_tag"
        log "  Platform: $platform"
        log "  Export date: $export_date"
        if [ -n "${git_branch:-}" ]; then
            log "  Git branch: $git_branch"
            log "  Git commit: $git_commit_short"
            log "  Git subject: $git_subject"
            log "  Git dirty: $git_dirty"
        fi
        echo
    fi

    log "Use 'promote VERSION' to promote a tested version to :latest"
}

# Promote a version to latest
promote_version() {
    local version_tag="$1"

    if [ -z "$version_tag" ]; then
        error "Version tag required"
        echo "Usage: $0 promote VERSION"
        echo "Example: $0 promote 20250915-185432-arm-a1b2c3d"
        echo ""
        echo "Available versions:"
        list_versions
        exit 1
    fi

    local full_tag="${IMAGE_NAME}:${version_tag}"

    # Check if the version exists
    if ! docker image inspect "$full_tag" >/dev/null 2>&1; then
        error "Version $version_tag not found locally"
        echo ""
        echo "Available versions:"
        list_versions
        exit 1
    fi

    # Determine architecture from tag
    local arch="unknown"
    if [[ "$version_tag" == *"-arm-"* ]]; then
        arch="arm"
    elif [[ "$version_tag" == *"-amd64-"* ]]; then
        arch="amd64"
    fi

    if [ "$arch" = "unknown" ]; then
        warning "Cannot determine architecture from tag, using image inspection"
        arch=$(docker image inspect "$full_tag" --format='{{.Architecture}}' 2>/dev/null || echo "unknown")
    fi

    log "Promoting version $version_tag to :latest"
    log "Architecture: $arch"

    # Tag as latest
    docker tag "$full_tag" "${IMAGE_NAME}:latest"
    docker tag "$full_tag" "${IMAGE_NAME}:latest-${arch}"

    success "✅ Promoted $version_tag to :latest"
    success "✅ Tagged as: ${IMAGE_NAME}:latest"
    success "✅ Tagged as: ${IMAGE_NAME}:latest-${arch}"

    echo
    log "Current :latest images:"
    docker images "${IMAGE_NAME}" | grep -E "latest|${version_tag}"
}

# Deploy to remote Pi
deploy_remote() {
    local ssh_target="$1"

    if [ -z "$ssh_target" ]; then
        error "SSH target not specified"
        echo "Usage: $0 deploy-remote user@hostname"
        exit 1
    fi

    parse_ssh_target "$ssh_target"

    log "Deploying native MediaMTX binaries to remote Pi: $SSH_TARGET"

    # Check if tarball exists
    local export_dir="$SCRIPT_DIR/export"
    local latest_tarball=$(ls -t "$export_dir"/rew-receiver-native-*.tar.gz 2>/dev/null | head -1)

    if [ -z "$latest_tarball" ]; then
        log "No deployment tarball found, creating one..."
        create_tarball
        latest_tarball=$(ls -t "$export_dir"/rew-receiver-native-*.tar.gz 2>/dev/null | head -1)
    fi

    log "Using tarball: $(basename "$latest_tarball")"

    # SSH options
    local ssh_opts="-o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no"

    # Test SSH connectivity
    log "Testing SSH connectivity to $SSH_TARGET..."
    if ! ssh $ssh_opts "$SSH_TARGET" "echo 'SSH test successful'" 2>/dev/null; then
        error "SSH connection failed to $SSH_TARGET"
        exit 1
    fi

    success "SSH connectivity verified"

    # Transfer deployment tarball
    log "Transferring native deployment package..."
    scp $ssh_opts "$latest_tarball" "$SSH_TARGET:~/"

    success "Deployment package transferred"

    # Extract and install on remote Pi
    local tarball_name=$(basename "$latest_tarball")
    log "Installing native MediaMTX + CamillaDSP on remote Pi..."
    ssh $ssh_opts "$SSH_TARGET" "
        tar -xzf '$tarball_name' &&
        cd '$PACKAGE_NAME' &&
        ./install.sh
    "

    success "Native MediaMTX deployment completed!"
    echo
    echo "🔗 Next Steps:"
    echo "1. SSH to Pi: ssh $SSH_TARGET"
    echo "2. Test API: curl http://$SSH_HOST:9997/v3/config"
    echo "3. View logs: ssh $SSH_TARGET 'sudo journalctl -u mediamtx -u camilladsp -f'"
    echo "4. Configure REW: Send RTP to $SSH_HOST:5004"
    echo "5. Check status: ssh $SSH_TARGET 'sudo systemctl status mediamtx camilladsp'"
}

# Test ARM container with emulation
test_arm_container() {
    log "Testing ARM container with Docker emulation..."
    
    if [ -f "$SCRIPT_DIR/test-arm-docker.sh" ]; then
        cd "$SCRIPT_DIR"
        ./test-arm-docker.sh
    else
        error "test-arm-docker.sh not found"
        echo "Make sure you're in the pi-receiver directory"
        exit 1
    fi
}

# Show container logs
show_logs() {
    log "Showing MediaMTX container logs..."
    docker logs -f "$CONTAINER_NAME" 2>/dev/null || {
        error "Container not found or not running"
        echo "Deploy first: $0 deploy"
        exit 1
    }
}

# Show container status
show_status() {
    log "MediaMTX container status:"
    echo
    
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        
        if docker ps --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
            success "Container is running"
            
            # Test MediaMTX API
            if curl -sf http://localhost:9997/v3/config >/dev/null 2>&1; then
                success "MediaMTX API is responding"
            else
                warning "MediaMTX API not responding"
            fi
            
            # Show recent log entries
            echo
            echo "Recent log entries:"
            docker logs --tail 10 "$CONTAINER_NAME"
        else
            warning "Container is not running"
        fi
    else
        warning "Container not found"
        echo "Deploy first: $0 deploy"
    fi
}

# Start container
start_container() {
    log "Starting MediaMTX container..."
    cd "$SCRIPT_DIR"
    
    if docker compose version >/dev/null 2>&1; then
        docker compose start
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose start
    else
        error "Docker Compose not found"
        exit 1
    fi
    
    success "MediaMTX container started"
}

# Stop container
stop_container() {
    log "Stopping MediaMTX container..."
    cd "$SCRIPT_DIR"
    
    if docker compose version >/dev/null 2>&1; then
        docker compose stop
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose stop
    else
        error "Docker Compose not found"
        exit 1
    fi
    
    success "MediaMTX container stopped"
}

# Clean up container and image
clean_up() {
    log "Cleaning up MediaMTX container and images..."
    
    # Stop and remove container
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Remove images
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
    docker rmi $(docker images "${IMAGE_NAME}" -q) 2>/dev/null || true
    
    # Remove unused volumes
    docker volume prune -f
    
    success "MediaMTX cleanup complete"
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
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            --test-with-container)
                TEST_WITH_CONTAINER=true
                shift
                ;;
            download|build|package|start|stop|logs|status|clean|test-container|list-versions)
                command="$1"
                shift
                ;;
            deploy-remote)
                command="deploy-remote"
                ssh_target="$2"
                shift 2
                ;;
            promote)
                command="promote"
                version_arg="$2"
                shift 2
                ;;
            *)
                error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$command" ]; then
        show_usage
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Execute command
    case $command in
        download)
            download_binaries
            create_package
            ;;
        build)
            if [ "$TEST_WITH_CONTAINER" = "true" ]; then
                build_image "${PLATFORM:-linux/amd64}"
            else
                warning "Build command is for container testing only. Use 'download' to get native binaries."
                echo "To test with containers, use: $0 --test-with-container build"
                exit 1
            fi
            ;;
        package)
            create_package
            create_tarball
            ;;
        deploy-remote)
            deploy_remote "$ssh_target"
            ;;
        promote)
            promote_version "$version_arg"
            ;;
        list-versions)
            list_versions
            ;;
        start)
            log "Starting native MediaMTX and CamillaDSP services..."
            sudo systemctl start mediamtx camilladsp
            success "Native services started"
            ;;
        stop)
            log "Stopping native MediaMTX and CamillaDSP services..."
            sudo systemctl stop mediamtx camilladsp
            success "Native services stopped"
            ;;
        logs)
            log "Showing native service logs..."
            sudo journalctl -u mediamtx -u camilladsp -f
            ;;
        status)
            log "Native service status:"
            sudo systemctl status mediamtx camilladsp --no-pager
            ;;
        clean)
            log "Cleaning native installation..."
            sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
            sudo systemctl disable mediamtx camilladsp 2>/dev/null || true
            sudo rm -f /etc/systemd/system/mediamtx.service /etc/systemd/system/camilladsp.service
            sudo systemctl daemon-reload
            sudo rm -rf /home/pi/rew-receiver
            success "Native installation cleaned"
            ;;
        test-container)
            test_arm_container
            ;;
        *)
            error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"