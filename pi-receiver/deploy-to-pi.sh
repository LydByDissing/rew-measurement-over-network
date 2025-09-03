#!/bin/bash
#
# REW Pi Audio Receiver - Deployment Script
# Automates Docker deployment to Raspberry Pi
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="rew-pi-receiver"
CONTAINER_NAME="rew-pi-audio-receiver"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
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

# Show usage
show_usage() {
    cat << EOF
REW Pi Audio Receiver - Deployment Script

Usage: $0 [OPTIONS] COMMAND

Commands:
    build               Build Docker image locally
    build-pi            Build ARM image for Raspberry Pi
    deploy              Deploy to local Docker
    deploy-remote HOST  Deploy to remote Pi via SSH
    start               Start the container
    stop                Stop the container
    logs                Show container logs
    status              Show container status
    clean               Remove container and image
    
Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cache          Build without using cache
    --platform ARCH     Target platform (linux/arm/v6, linux/amd64)

Examples:
    $0 build                                # Build x86 image locally
    $0 build-pi                            # Build ARM image for Pi
    $0 deploy                              # Deploy locally
    $0 deploy-remote pi@192.168.1.100     # Deploy to remote Pi
    $0 logs                                # View container logs
    $0 status                              # Check container status

Environment file:
    Copy .env.example to .env and customize for your setup.
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
    
    log "Building Docker image for platform: $platform"
    
    if command -v docker buildx >/dev/null 2>&1; then
        log "Using Docker Buildx for cross-platform build"
        docker buildx build \
            --platform "$platform" \
            --tag "${IMAGE_NAME}:latest" \
            --tag "${IMAGE_NAME}:$(date +%Y%m%d)" \
            $cache_flag \
            --load \
            "$SCRIPT_DIR"
    else
        log "Using standard Docker build"
        docker build \
            --tag "${IMAGE_NAME}:latest" \
            --tag "${IMAGE_NAME}:$(date +%Y%m%d)" \
            $cache_flag \
            "$SCRIPT_DIR"
    fi
    
    success "Docker image built successfully"
}

# Deploy container
deploy_container() {
    log "Deploying REW Pi Audio Receiver container..."
    
    cd "$SCRIPT_DIR"
    
    # Check for environment file
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            log "Creating .env file from template"
            cp .env.example .env
            warning "Please customize .env file for your setup"
        else
            warning "No .env file found - using defaults"
        fi
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
    log "Starting container with $COMPOSE_CMD"
    $COMPOSE_CMD up -d
    
    # Wait for container to be ready
    log "Waiting for container to start..."
    sleep 5
    
    # Check container status
    if docker ps | grep -q "$CONTAINER_NAME"; then
        success "Container deployed successfully"
        echo
        echo "Container Status:"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "View logs: $0 logs"
        echo "Check status: $0 status"
    else
        error "Container failed to start"
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
    local export_dir="$SCRIPT_DIR/export"
    local tarball_name="rew-pi-receiver-$(date +%Y%m%d).tar"
    
    log "Exporting Docker image for platform: $platform"
    
    # Build the image for the target platform
    build_image "$platform"
    
    # Create export directory
    mkdir -p "$export_dir"
    
    # Export the image as tarball
    log "Exporting image to tarball: $export_dir/$tarball_name"
    docker save "${IMAGE_NAME}:latest" -o "$export_dir/$tarball_name"
    
    # Create deployment package with docker-compose and install script
    log "Creating deployment package..."
    
    # Copy docker-compose and .env files
    cp "$SCRIPT_DIR/docker-compose.yaml" "$export_dir/"
    if [ -f "$SCRIPT_DIR/.env" ]; then
        cp "$SCRIPT_DIR/.env" "$export_dir/"
    else
        cp "$SCRIPT_DIR/.env.example" "$export_dir/.env"
    fi
    
    # Create install script for Pi
    cat > "$export_dir/install-from-tarball.sh" << 'EOF'
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

echo "🥧 REW Pi Receiver - Tarball Installation"
echo "========================================"

TARBALL=$(ls -1 rew-pi-receiver-*.tar 2>/dev/null | head -1)
if [ -z "$TARBALL" ]; then
    error "No REW Pi receiver tarball found (rew-pi-receiver-*.tar)"
    exit 1
fi

log "Found tarball: $TARBALL"

if docker ps | grep -q "rew-pi-audio-receiver"; then
    log "Stopping existing container..."
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || docker stop rew-pi-audio-receiver 2>/dev/null || true
fi

if docker images | grep -q "rew-pi-receiver"; then
    log "Removing old image..."
    docker rmi rew-pi-receiver:latest 2>/dev/null || true
fi

log "Loading Docker image from tarball..."
docker load -i "$TARBALL"

success "Image loaded successfully"

if [ ! -f "docker-compose.yaml" ]; then
    error "docker-compose.yaml not found in deployment package"
    exit 1
fi

if [ ! -f ".env" ]; then
    warning "No .env file found - using defaults"
fi

log "Deploying REW Pi receiver container..."
docker compose up -d || docker-compose up -d

sleep 3

if docker ps | grep -q "rew-pi-audio-receiver"; then
    success "REW Pi receiver deployed successfully!"
    echo
    echo "📊 Container Status:"
    docker compose ps || docker-compose ps
    echo
    echo "🔗 Next Steps:"
    echo "• Check status: curl http://localhost:8080/status"
    echo "• View logs: docker compose logs -f"
    echo "• Stop: docker compose down"
else
    error "Container failed to start"
    echo "Check logs with: docker compose logs"
    exit 1
fi
EOF
    
    chmod +x "$export_dir/install-from-tarball.sh"
    
    success "Export package created in: $export_dir"
    echo "Contents:"
    ls -la "$export_dir"
    echo
    echo "To deploy to Pi:"
    echo "1. scp -r $export_dir/ pi@pi-ip:~/rew-deployment/"
    echo "2. ssh pi@pi-ip 'cd ~/rew-deployment && ./install-from-tarball.sh'"
}

# Deploy tarball to remote Pi
deploy_tarball() {
    local ssh_target="$1"
    
    if [ -z "$ssh_target" ]; then
        error "SSH target not specified"
        echo "Usage: $0 deploy-tarball user@hostname"
        exit 1
    fi
    
    # Parse SSH target
    parse_ssh_target "$ssh_target"
    
    log "Deploying via tarball to remote Pi: $SSH_TARGET"
    
    # Check if export directory exists
    local export_dir="$SCRIPT_DIR/export"
    if [ ! -d "$export_dir" ]; then
        log "No export directory found - creating deployment package first..."
        export_image "linux/arm/v6"
    fi
    
    # Check if deployment package exists
    if [ ! -f "$export_dir/install-from-tarball.sh" ]; then
        error "Deployment package not found. Run: $0 export"
        exit 1
    fi
    
    # SSH options
    local ssh_opts="-o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no"
    local ssh_key=""
    
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        ssh_key="-i $HOME/.ssh/id_rsa"
    elif [ -f "$HOME/.ssh/id_ed25519" ]; then
        ssh_key="-i $HOME/.ssh/id_ed25519"
    fi
    
    # Test SSH connectivity
    log "Testing SSH connectivity to $SSH_TARGET..."
    if ! ssh $ssh_opts $ssh_key "$SSH_TARGET" "echo 'SSH test successful'" 2>/dev/null; then
        error "SSH connection failed to $SSH_TARGET"
        echo "Try: $0 setup-ssh $SSH_TARGET"
        exit 1
    fi
    
    success "SSH connectivity verified"
    
    # Create remote directory
    log "Creating remote directory ~/rew-deployment..."
    ssh $ssh_opts $ssh_key "$SSH_TARGET" "mkdir -p ~/rew-deployment"
    
    # Transfer deployment package
    log "Transferring deployment package..."
    scp $ssh_opts $ssh_key -r "$export_dir"/* "$SSH_TARGET:~/rew-deployment/"
    
    success "Deployment package transferred"
    
    # Execute remote installation
    log "Installing on remote Pi..."
    ssh $ssh_opts $ssh_key "$SSH_TARGET" "cd ~/rew-deployment && ./install-from-tarball.sh"
    
    success "Tarball deployment completed!"
    echo
    echo "🔗 Next Steps:"
    echo "1. SSH to Pi: ssh $SSH_TARGET"
    echo "2. Check status: curl http://$SSH_HOST:8080/status"
    echo "3. View logs: cd ~/rew-deployment && docker compose logs -f"
}

# Deploy to remote Pi
deploy_remote() {
    local ssh_target="$1"
    
    if [ -z "$ssh_target" ]; then
        error "SSH target not specified"
        echo "Usage: $0 deploy-remote user@hostname"
        exit 1
    fi
    
    log "Deploying to remote Pi: $ssh_target"
    
    # Create deployment package
    local temp_dir=$(mktemp -d)
    log "Creating deployment package in $temp_dir"
    
    cp -r "$SCRIPT_DIR"/* "$temp_dir/"
    
    # Create deployment script
    cat > "$temp_dir/remote-deploy.sh" << 'EOF'
#!/bin/bash
set -e

echo "🥧 REW Pi Audio Receiver - Remote Deployment"
echo "============================================"

# Update system packages
echo "Updating system packages..."
sudo apt-get update

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if not present
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "Installing Docker Compose..."
    sudo apt-get install -y docker-compose-plugin
fi

# Build and deploy
echo "Building and deploying REW Pi Audio Receiver..."
./deploy-to-pi.sh build-pi
./deploy-to-pi.sh deploy

echo "🎉 Deployment complete!"
echo "The REW Pi Audio Receiver is now running."
EOF
    
    chmod +x "$temp_dir/remote-deploy.sh"
    
    # Transfer files
    log "Transferring files to Pi..."
    scp -r "$temp_dir"/* "$ssh_target:~/rew-receiver/"
    
    # Execute remote deployment
    log "Executing remote deployment..."
    ssh "$ssh_target" "cd ~/rew-receiver && ./remote-deploy.sh"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    success "Remote deployment completed successfully"
}

# Show container logs
show_logs() {
    log "Showing container logs..."
    docker logs -f "$CONTAINER_NAME" 2>/dev/null || {
        error "Container not found or not running"
        echo "Deploy first: $0 deploy"
        exit 1
    }
}

# Show container status
show_status() {
    log "Container status:"
    echo
    
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        
        if docker ps --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
            success "Container is running"
            
            # Try to get health status
            if docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
                success "Container health check: healthy"
            elif docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "unhealthy"; then
                warning "Container health check: unhealthy"
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
    log "Starting container..."
    cd "$SCRIPT_DIR"
    
    if docker compose version >/dev/null 2>&1; then
        docker compose start
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose start
    else
        error "Docker Compose not found"
        exit 1
    fi
    
    success "Container started"
}

# Stop container
stop_container() {
    log "Stopping container..."
    cd "$SCRIPT_DIR"
    
    if docker compose version >/dev/null 2>&1; then
        docker compose stop
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose stop
    else
        error "Docker Compose not found"
        exit 1
    fi
    
    success "Container stopped"
}

# Clean up container and image
clean_up() {
    log "Cleaning up container and images..."
    
    # Stop and remove container
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Remove images
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
    docker rmi $(docker images "${IMAGE_NAME}" -q) 2>/dev/null || true
    
    # Remove unused volumes
    docker volume prune -f
    
    success "Cleanup complete"
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
            build|build-pi|export|deploy|start|stop|logs|status|clean)
                command="$1"
                shift
                ;;
            deploy-remote)
                command="deploy-remote"
                ssh_target="$2"
                shift 2
                ;;
            deploy-tarball)
                command="deploy-tarball"
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
        deploy-tarball)
            deploy_tarball "$ssh_target"
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
        *)
            error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"