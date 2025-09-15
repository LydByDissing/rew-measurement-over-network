#!/bin/bash
#
# REW MediaMTX Audio Receiver - Deployment Script
# Simplified deployment for MediaMTX + CamillaDSP containers only
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="rew-mediamtx-receiver"
CONTAINER_NAME="rew-mediamtx-audio-receiver"

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

        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            git_hash="${git_hash}-dirty"
        fi

        # Check for untracked files in pi-receiver directory
        local untracked_count=$(git ls-files --others --exclude-standard "$SCRIPT_DIR" 2>/dev/null | wc -l)
        if [ "$untracked_count" -gt 0 ]; then
            git_hash="${git_hash}-u${untracked_count}"
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

        # Show git status summary
        local modified=$(git diff-index --name-only HEAD -- 2>/dev/null | wc -l)
        local untracked=$(git ls-files --others --exclude-standard "$SCRIPT_DIR" 2>/dev/null | wc -l)

        if [ "$modified" -gt 0 ] || [ "$untracked" -gt 0 ]; then
            warning "Working directory has uncommitted changes:"
            [ "$modified" -gt 0 ] && warning "  Modified files: $modified"
            [ "$untracked" -gt 0 ] && warning "  Untracked files in pi-receiver/: $untracked"
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
    build               Build Docker image locally (creates unique version)
    build-pi            Build ARM image for Raspberry Pi
    deploy              Deploy to local Docker
    deploy-remote HOST  Deploy to remote Pi via SSH
    promote VERSION     Promote a version tag to :latest
    list-versions       List available image versions
    start               Start the container
    stop                Stop the container
    logs                Show container logs
    status              Show container status
    clean               Remove container and image
    test-arm            Test ARM container with emulation
    
Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cache          Build without using cache
    --platform ARCH     Target platform (linux/arm/v6, linux/amd64)
    --use-cached        Use existing ARM image (skip force rebuild for deploy-remote)

Examples:
    $0 build                                # Build x86 image (creates unique version)
    $0 build-pi                            # Build ARM image for Pi
    $0 list-versions                       # Show available image versions
    $0 deploy                              # Deploy locally
    $0 deploy-remote pi@192.168.1.100     # Deploy to remote Pi (auto-builds ARM)
    $0 promote 20250915-185432-arm-a1b2c3d # Promote tested version to :latest
    $0 test-arm                            # Test ARM container locally
    $0 logs                                # View container logs
    $0 status                              # Check container status

Deployment Workflow:
    1. Build: $0 build-pi                               # Creates unique ARM version
    2. Deploy: $0 deploy-remote pi@IP                   # Deploys latest ARM version
    3. Test: Test on Pi, verify audio works
    4. Promote: $0 promote VERSION                      # Promote working version to :latest

Version Management:
    $0 list-versions                                    # Show all built versions
    $0 promote 20250915-185432-arm-a1b2c3d             # Promote specific version

This script deploys the MediaMTX + CamillaDSP container approach only.
The legacy Python container has been removed due to ARM timestamp issues.
EOF
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing+=("docker")
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        missing+=("docker-compose")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        echo "Please install Docker and Docker Compose first."
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

# Build Docker image
build_image() {
    local platform="${1:-$(detect_arch)}"
    local cache_flag=""

    if [ "$NO_CACHE" = "true" ]; then
        cache_flag="--no-cache"
    fi

    # Generate unique version tag
    local unique_tag=$(generate_unique_tag "$platform")
    local arch=$(get_arch_suffix "$platform")
    local build_date=$(date +%Y%m%d)

    log "Building MediaMTX Docker image for platform: $platform"
    log "Unique version tag: $unique_tag"

    # Show git context for traceability
    show_git_context

    if command -v docker buildx >/dev/null 2>&1; then
        log "Using Docker Buildx for cross-platform build"
        docker buildx build \
            --platform "$platform" \
            --tag "${IMAGE_NAME}:${unique_tag}" \
            --tag "${IMAGE_NAME}:latest-${arch}" \
            --tag "${IMAGE_NAME}:${build_date}" \
            $cache_flag \
            --load \
            "$SCRIPT_DIR"
    else
        log "Using standard Docker build"
        docker build \
            --tag "${IMAGE_NAME}:${unique_tag}" \
            --tag "${IMAGE_NAME}:latest-${arch}" \
            --tag "${IMAGE_NAME}:${build_date}" \
            $cache_flag \
            "$SCRIPT_DIR"
    fi

    # Save the version information
    save_version_tag "$arch" "$unique_tag"

    success "MediaMTX Docker image built successfully!"
    success "✅ Unique tag: ${IMAGE_NAME}:${unique_tag}"
    success "✅ Latest tag: ${IMAGE_NAME}:latest-${arch}"

    # Export the unique tag for use by calling functions
    LAST_BUILT_TAG="$unique_tag"
}

# Deploy container
deploy_container() {
    log "Deploying MediaMTX Audio Receiver container..."
    
    cd "$SCRIPT_DIR"
    
    # Check for environment file
    if [ ! -f .env ]; then
        warning "No .env file found - using container defaults"
        echo "# REW MediaMTX Audio Receiver - Environment Configuration" > .env
        echo "" >> .env
        echo "# Pi identification" >> .env
        echo "PI_HOSTNAME=rew-pi-mediamtx" >> .env
        echo "" >> .env
        echo "# Timezone" >> .env
        echo "TZ=UTC" >> .env
        echo "" >> .env
        echo "# Logging level" >> .env
        echo "LOG_LEVEL=info" >> .env
        echo "" >> .env
        echo "# Docker Compose project name" >> .env
        echo "COMPOSE_PROJECT_NAME=rew-mediamtx" >> .env
    fi
    
    # Use docker compose (modern) or docker-compose (legacy)
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        error "Docker Compose not found"
        exit 1
    fi
    
    # Deploy the container
    log "Starting MediaMTX container with $COMPOSE_CMD"
    $COMPOSE_CMD up -d
    
    # Wait for container to be ready
    log "Waiting for container to start..."
    sleep 5
    
    # Check container status
    if docker ps | grep -q "$CONTAINER_NAME"; then
        success "MediaMTX container deployed successfully"
        echo
        echo "Container Status:"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "🔗 Access Points:"
        echo "• MediaMTX API: http://localhost:9997/v3/config"
        echo "• RTP Input: localhost:5004"
        echo "• RTSP Stream: rtsp://localhost:8554/"
        echo
        echo "🔧 Management:"
        echo "• View logs: $0 logs"
        echo "• Check status: $0 status"
        echo "• Stop: $0 stop"
    else
        error "MediaMTX container failed to start"
        echo "Check logs: $0 logs"
        exit 1
    fi
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

# Export Docker image as tarball for Pi deployment
export_image() {
    local platform="${1:-linux/arm/v6}"
    local force_rebuild="${2:-false}"
    local export_dir="$SCRIPT_DIR/export"

    local target_arch=$(get_arch_suffix "$platform")
    local latest_tag="${IMAGE_NAME}:latest-${target_arch}"

    log "Exporting MediaMTX Docker image for platform: $platform"

    # Determine which image to export
    local export_tag=""
    local needs_build=false

    if [ "$force_rebuild" = "true" ]; then
        log "Force rebuild requested - building fresh image for platform: $platform"
        build_image "$platform"
        export_tag="${IMAGE_NAME}:${LAST_BUILT_TAG}"
    else
        # Check if we have a recent image for this architecture
        local stored_version=$(get_latest_version_tag "$target_arch")
        if [ -n "$stored_version" ] && docker image inspect "${IMAGE_NAME}:${stored_version}" >/dev/null 2>&1; then
            log "Using existing version: ${stored_version}"
            export_tag="${IMAGE_NAME}:${stored_version}"
        elif docker image inspect "$latest_tag" >/dev/null 2>&1; then
            log "Using latest-${target_arch} tag"
            export_tag="$latest_tag"
        else
            log "No suitable image found - building fresh image for platform: $platform"
            build_image "$platform"
            export_tag="${IMAGE_NAME}:${LAST_BUILT_TAG}"
        fi
    fi
    
    # Create export directory
    mkdir -p "$export_dir"

    # Generate tarball name with version info
    local version_tag=$(echo "$export_tag" | cut -d: -f2)
    local tarball_name="${IMAGE_NAME}-${version_tag}.tar"

    # Clean up old tarballs first
    log "Cleaning up old image tarballs..."
    rm -f "$export_dir"/${IMAGE_NAME}-*.tar

    # Export the image as tarball
    log "Exporting image to tarball: $export_dir/$tarball_name"
    log "Using image tag: $export_tag"
    docker save "$export_tag" -o "$export_dir/$tarball_name"

    # Save export info for tracking
    echo "export_tag=${export_tag}" > "$export_dir/.export-info"
    echo "tarball=${tarball_name}" >> "$export_dir/.export-info"
    echo "platform=${platform}" >> "$export_dir/.export-info"
    echo "export_date=$(date -Iseconds)" >> "$export_dir/.export-info"

    # Add git context to export info
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_commit=$(git rev-parse HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_commit_short=$(git rev-parse --short HEAD 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_subject=$(git log -1 --pretty=format:"%s" 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_author=$(git log -1 --pretty=format:"%an <%ae>" 2>/dev/null)" >> "$export_dir/.export-info"
        echo "git_date=$(git log -1 --pretty=format:"%ci" 2>/dev/null)" >> "$export_dir/.export-info"

        # Check for dirty state
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "git_dirty=true" >> "$export_dir/.export-info"
        else
            echo "git_dirty=false" >> "$export_dir/.export-info"
        fi
    fi
    
    # Create deployment package
    log "Creating deployment package..."

    # Copy docker-compose.yml (install script will tag the versioned image as :latest)
    cp "$SCRIPT_DIR/docker-compose.yml" "$export_dir/"
    if [ -f "$SCRIPT_DIR/.env" ]; then
        cp "$SCRIPT_DIR/.env" "$export_dir/"
    fi
    
    # Create install script
    cat > "$export_dir/install-mediamtx.sh" << 'EOF'
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🎵 REW MediaMTX Audio Receiver - Installation"
echo "============================================="

# Find the correct tarball - use the one specified in .export-info if available
if [ -f ".export-info" ]; then
    source ".export-info"
    TARBALL="$tarball"
    log "Using tarball from export info: $TARBALL"
else
    # Fallback: find the newest tarball by timestamp
    TARBALL=$(ls -t rew-mediamtx-receiver-*.tar 2>/dev/null | head -1)
    if [ -z "$TARBALL" ]; then
        error "No MediaMTX receiver tarball found (rew-mediamtx-receiver-*.tar)"
        exit 1
    fi
    warning "No export info found, using newest tarball: $TARBALL"
fi

# Verify the tarball exists
if [ ! -f "$TARBALL" ]; then
    error "Specified tarball not found: $TARBALL"
    echo "Available tarballs:"
    ls -la rew-mediamtx-receiver-*.tar 2>/dev/null || echo "  None found"
    exit 1
fi

log "Using tarball: $TARBALL"

# Stop existing container
if docker ps | grep -q "rew-mediamtx-audio-receiver"; then
    log "Stopping existing container..."
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
fi

# Remove old images and tarballs to prevent confusion
if docker images | grep -q "rew-mediamtx-receiver"; then
    log "Removing old images..."
    docker rmi rew-mediamtx-receiver:latest 2>/dev/null || true
    # Remove other tagged versions except the one we're about to load
    docker images rew-mediamtx-receiver --format "{{.Tag}}" | grep -v "^latest$" | head -10 | while read tag; do
        if [ "$tag" != "$(basename "$TARBALL" .tar | sed 's/rew-mediamtx-receiver-//')" ]; then
            docker rmi "rew-mediamtx-receiver:$tag" 2>/dev/null || true
        fi
    done
fi

# Clean up old tarballs (keep only the current one)
log "Cleaning up old tarballs..."
ls rew-mediamtx-receiver-*.tar 2>/dev/null | grep -v "$(basename "$TARBALL")" | head -5 | while read old_tarball; do
    log "Removing old tarball: $old_tarball"
    rm -f "$old_tarball"
done

log "Loading MediaMTX Docker image from tarball..."

# Extract expected tag from tarball filename
EXPECTED_TAG=$(basename "$TARBALL" .tar | sed 's/rew-mediamtx-receiver-//')
log "Expected image tag from tarball: $EXPECTED_TAG"

# Load the image and capture the output to get the actual loaded tag
LOAD_OUTPUT=$(docker load -i "$TARBALL" 2>&1)
echo "$LOAD_OUTPUT"

# Extract the loaded image tag from docker load output or use expected tag
LOADED_TAG=""
if echo "$LOAD_OUTPUT" | grep -q "Loaded image:"; then
    LOADED_TAG=$(echo "$LOAD_OUTPUT" | grep "Loaded image:" | sed 's/.*: *//' | cut -d: -f2)
    log "Detected loaded tag from output: $LOADED_TAG"
elif docker image inspect "rew-mediamtx-receiver:$EXPECTED_TAG" >/dev/null 2>&1; then
    LOADED_TAG="$EXPECTED_TAG"
    log "Using expected tag: $LOADED_TAG"
else
    error "Could not determine loaded image tag"
    exit 1
fi

# Tag the specific loaded image as latest for docker-compose compatibility
if [ -n "$LOADED_TAG" ] && [ "$LOADED_TAG" != "latest" ]; then
    log "Tagging loaded image $LOADED_TAG as latest..."
    docker tag "rew-mediamtx-receiver:$LOADED_TAG" "rew-mediamtx-receiver:latest"
else
    error "Invalid loaded tag: $LOADED_TAG"
    exit 1
fi

success "Image loaded successfully"
docker images | grep rew-mediamtx-receiver

# Verify we're using the correct image by checking export info
if [ -f ".export-info" ]; then
    source ".export-info"
    CURRENT_IMAGE_ID=$(docker image inspect "rew-mediamtx-receiver:latest" --format='{{.Id}}' 2>/dev/null | cut -d: -f2 | cut -c1-12)
    log "Current latest image ID: $CURRENT_IMAGE_ID"
    log "Expected from export: ${export_tag}"
    if [ -n "$git_commit_short" ]; then
        log "Git commit: $git_commit_short (dirty: ${git_dirty:-unknown})"
    fi
fi

if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found in deployment package"
    exit 1
fi

if [ ! -f ".env" ]; then
    warning "No .env file found - using defaults"
fi

log "Deploying MediaMTX audio receiver container..."
docker compose up -d || docker-compose up -d

sleep 5

if docker ps | grep -q "rew-mediamtx-audio-receiver"; then
    success "MediaMTX audio receiver deployed successfully!"
    echo
    echo "📊 Container Status:"
    docker ps | grep mediamtx
    echo
    echo "🔗 Access Points:"
    PI_IP=$(hostname -I | awk '{print $1}')
    echo "• MediaMTX API: http://$PI_IP:9997/v3/config"
    echo "• RTP Input: $PI_IP:5004"
    echo "• RTSP Stream: rtsp://$PI_IP:8554/"
    echo
    echo "🔧 Management:"
    echo "• View logs: docker logs rew-mediamtx-audio-receiver -f"
    echo "• Restart: docker restart rew-mediamtx-audio-receiver"
    echo "• Stop: docker compose down"
else
    error "Container failed to start"
    echo "Check logs with: docker logs rew-mediamtx-audio-receiver"
    exit 1
fi
EOF
    
    chmod +x "$export_dir/install-mediamtx.sh"
    
    success "Export package created in: $export_dir"
    success "✅ Image version: $version_tag"
    success "✅ Tarball: $tarball_name"
    echo "Contents:"
    ls -la "$export_dir"
    echo
    echo "📦 To deploy to Pi:"
    echo "1. scp -r $export_dir/ pi@pi-ip:~/rew-mediamtx/"
    echo "2. ssh pi@pi-ip 'cd ~/rew-mediamtx && ./install-mediamtx.sh'"
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

    log "Deploying MediaMTX container to remote Pi: $SSH_TARGET"

    # Build ARM image for Pi deployment
    local export_dir="$SCRIPT_DIR/export"

    if [ "${USE_CACHED:-false}" = "true" ]; then
        log "Using cached ARM image (if available) due to --use-cached flag"
        export_image "linux/arm/v6" "false"
    else
        log "Building fresh ARM image for Pi deployment (this ensures latest changes)..."
        log "This may take a few minutes depending on your system..."
        log "Use --use-cached flag to skip rebuild if you have a recent ARM image"
        # Force rebuild ARM image and export
        export_image "linux/arm/v6" "true"
    fi
    
    # SSH options
    local ssh_opts="-o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no"
    
    # Test SSH connectivity
    log "Testing SSH connectivity to $SSH_TARGET..."
    if ! ssh $ssh_opts "$SSH_TARGET" "echo 'SSH test successful'" 2>/dev/null; then
        error "SSH connection failed to $SSH_TARGET"
        exit 1
    fi
    
    success "SSH connectivity verified"
    
    # Create remote directory
    log "Creating remote directory ~/rew-mediamtx..."
    ssh $ssh_opts "$SSH_TARGET" "mkdir -p ~/rew-mediamtx"
    
    # Transfer deployment package
    log "Transferring MediaMTX deployment package..."
    scp $ssh_opts -r "$export_dir"/* "$SSH_TARGET:~/rew-mediamtx/"
    
    success "Deployment package transferred"
    
    # Execute remote installation
    log "Installing MediaMTX container on remote Pi..."
    ssh $ssh_opts "$SSH_TARGET" "cd ~/rew-mediamtx && ./install-mediamtx.sh"
    
    success "MediaMTX container deployment completed!"
    echo
    echo "🔗 Next Steps:"
    echo "1. SSH to Pi: ssh $SSH_TARGET"
    echo "2. Test API: curl http://$SSH_HOST:9997/v3/config"
    echo "3. View logs: ssh $SSH_TARGET 'docker logs rew-mediamtx-audio-receiver -f'"
    echo "4. Configure REW: Send RTP to $SSH_HOST:5004"
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
            --use-cached)
                USE_CACHED=true
                shift
                ;;
            build|build-pi|export|deploy|start|stop|logs|status|clean|test-arm|list-versions)
                command="$1"
                shift
                ;;
            promote)
                command="promote"
                version_arg="$2"
                shift 2
                ;;
            deploy-remote)
                command="deploy-remote"
                ssh_target="$2"
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
        build)
            build_image "${PLATFORM:-linux/amd64}"
            ;;
        build-pi)
            build_image "linux/arm/v6"
            ;;
        export)
            export_image "${PLATFORM:-linux/arm/v6}"
            ;;
        deploy)
            build_image
            deploy_container
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
            start_container
            ;;
        stop)
            stop_container
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        clean)
            clean_up
            ;;
        test-arm)
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