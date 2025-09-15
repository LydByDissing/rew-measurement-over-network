#!/bin/bash
#
# Quick MediaMTX Container Deployment Script
# Simplified deployment for MediaMTX container only
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[MEDIAMTX]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="rew-mediamtx-receiver"
CONTAINER_NAME="rew-mediamtx-audio-receiver"

show_usage() {
    cat << EOF
Quick MediaMTX Container Deployment

Usage: $0 COMMAND [PI_IP]

Commands:
    build               Build ARM MediaMTX container
    deploy PI_IP        Deploy to Raspberry Pi
    test-local          Test locally with ARM emulation
    status PI_IP        Check status on Pi
    logs PI_IP          View logs on Pi
    stop PI_IP          Stop container on Pi

Examples:
    $0 build                        # Build ARM container
    $0 deploy pi@192.168.1.100     # Deploy to Pi
    $0 test-local                   # Test with ARM emulation
    $0 status 192.168.1.100        # Check Pi status
    $0 logs 192.168.1.100          # View Pi logs

This script focuses only on the MediaMTX container approach.
For legacy Python container support, use deploy-to-pi.sh --legacy
EOF
}

build_container() {
    log "Building MediaMTX ARM container..."
    docker buildx build \
        --platform linux/arm/v6 \
        --file Dockerfile.mediamtx \
        --tag "${IMAGE_NAME}:arm" \
        --load \
        .
    success "ARM MediaMTX container built successfully"
}

deploy_to_pi() {
    local pi_target="$1"
    
    if [ -z "$pi_target" ]; then
        error "Pi IP address required"
        echo "Usage: $0 deploy pi@192.168.1.100"
        exit 1
    fi
    
    log "Deploying MediaMTX container to $pi_target..."
    
    # Check if ARM image exists
    if ! docker images | grep -q "${IMAGE_NAME}.*arm"; then
        log "ARM image not found - building first..."
        build_container
    fi
    
    # Export image
    log "Exporting ARM container..."
    docker save "${IMAGE_NAME}:arm" -o "${IMAGE_NAME}-arm.tar"
    
    # Create deployment directory on Pi
    log "Creating deployment directory on Pi..."
    ssh "$pi_target" "mkdir -p ~/rew-mediamtx"
    
    # Copy files to Pi
    log "Copying files to Pi..."
    scp "${IMAGE_NAME}-arm.tar" docker-compose.yml .env "$pi_target:~/rew-mediamtx/"
    
    # Deploy on Pi
    log "Loading and starting container on Pi..."
    ssh "$pi_target" "
        cd ~/rew-mediamtx && 
        docker load -i ${IMAGE_NAME}-arm.tar &&
        docker-compose down 2>/dev/null || true &&
        docker-compose up -d
    "
    
    # Clean up local tarball
    rm -f "${IMAGE_NAME}-arm.tar"
    
    success "MediaMTX container deployed successfully!"
    echo
    echo "🔗 Access Points:"
    local pi_ip=$(echo "$pi_target" | cut -d@ -f2)
    echo "• MediaMTX API: http://$pi_ip:9997/v3/config"
    echo "• RTP Input: $pi_ip:5004"
    echo "• RTSP Stream: rtsp://$pi_ip:8554/"
}

test_local() {
    log "Testing MediaMTX container with ARM emulation..."
    if [ -f "./test-arm-docker.sh" ]; then
        ./test-arm-docker.sh
    else
        error "test-arm-docker.sh not found"
        exit 1
    fi
}

check_status() {
    local pi_target="$1"
    
    if [ -z "$pi_target" ]; then
        error "Pi IP address required"
        exit 1
    fi
    
    log "Checking MediaMTX container status on $pi_target..."
    ssh "$pi_target" "docker ps | grep mediamtx || echo 'No MediaMTX containers running'"
    
    # Test API
    local pi_ip=$(echo "$pi_target" | cut -d@ -f2 2>/dev/null || echo "$pi_target")
    log "Testing MediaMTX API..."
    if curl -sf "http://$pi_ip:9997/v3/config" >/dev/null; then
        success "MediaMTX API responding"
    else
        warning "MediaMTX API not responding"
    fi
}

show_logs() {
    local pi_target="$1"
    
    if [ -z "$pi_target" ]; then
        error "Pi IP address required"
        exit 1
    fi
    
    log "Showing MediaMTX container logs on $pi_target..."
    ssh "$pi_target" "docker logs rew-mediamtx-audio-receiver -f"
}

stop_container() {
    local pi_target="$1"
    
    if [ -z "$pi_target" ]; then
        error "Pi IP address required"
        exit 1
    fi
    
    log "Stopping MediaMTX container on $pi_target..."
    ssh "$pi_target" "cd ~/rew-mediamtx && docker-compose down"
    success "MediaMTX container stopped"
}

main() {
    local command="$1"
    local target="$2"
    
    cd "$SCRIPT_DIR"
    
    case "$command" in
        build)
            build_container
            ;;
        deploy)
            deploy_to_pi "$target"
            ;;
        test-local)
            test_local
            ;;
        status)
            check_status "$target"
            ;;
        logs)
            show_logs "$target"
            ;;
        stop)
            stop_container "$target"
            ;;
        -h|--help|"")
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"