#!/bin/bash
#
# Build REW MediaMTX Audio Receiver Containers
# Builds MediaMTX containers for all target architectures
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="rew-mediamtx-receiver"

show_usage() {
    cat << EOF
Build REW MediaMTX Audio Receiver Containers

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --amd64-only        Build only AMD64 version (for local testing)
    --arm-only          Build only ARM versions (for Pi deployment)
    --no-cache          Build without using cache
    --export            Export ARM images as tarballs after building

Examples:
    $0                          # Build all architectures (AMD64 + ARM)
    $0 --arm-only               # Build only ARM versions for Pi
    $0 --export                 # Build all + export ARM tarballs
    $0 --amd64-only             # Build only for local testing

Artifacts built:
    • MediaMTX container (rew-mediamtx-receiver:latest)
    • ARM v6 version for Raspberry Pi Zero/1  
    • ARM v7 version for Raspberry Pi 4+
    • AMD64 version for local testing

Note: The legacy Python container has been removed due to ARM timestamp issues.
Only the reliable MediaMTX + CamillaDSP approach is supported.
EOF
}

build_architecture() {
    local platform="$1"
    local tag_suffix="$2"
    local no_cache_flag="$3"
    
    log "Building MediaMTX container for $platform..."
    
    DOCKER_BUILDKIT=1 docker buildx build \
        --platform "$platform" \
        --tag "${IMAGE_NAME}:${tag_suffix}" \
        $no_cache_flag \
        --load \
        .
        
    success "MediaMTX $platform container built successfully"
}

export_arm_images() {
    log "Exporting ARM images as deployment tarballs..."
    ./deploy-to-pi.sh export
    success "ARM images exported to ./export/ directory"
}

main() {
    local build_amd64=true
    local build_arm=true
    local export_images=false
    local no_cache=""
    
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
            --amd64-only)
                build_arm=false
                shift
                ;;
            --arm-only)
                build_amd64=false
                shift
                ;;
            --no-cache)
                no_cache="--no-cache"
                shift
                ;;
            --export)
                export_images=true
                shift
                ;;
            *)
                error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    cd "$SCRIPT_DIR"
    
    echo "🏗️  Building REW MediaMTX Audio Receiver Containers"
    echo "=================================================="
    
    # Build AMD64 version for local testing
    if [ "$build_amd64" = true ]; then
        build_architecture "linux/amd64" "amd64" "$no_cache"
        build_architecture "linux/amd64" "latest" "$no_cache"
    fi
    
    # Build ARM versions for Raspberry Pi
    if [ "$build_arm" = true ]; then
        # ARM v6 for Pi Zero/1
        build_architecture "linux/arm/v6" "arm-v6" "$no_cache"
        
        # ARM v7 for Pi 4+ (optional)
        log "Building ARM v7 version for Pi 4+ (optional)..."
        build_architecture "linux/arm/v7" "arm-v7" "$no_cache" || {
            warning "ARM v7 build failed - this is optional, ARM v6 works on all Pi models"
        }
        
        # Tag ARM v6 as default ARM version
        docker tag "${IMAGE_NAME}:arm-v6" "${IMAGE_NAME}:arm"
        success "ARM v6 tagged as default ARM version"
    fi
    
    # Export ARM images if requested
    if [ "$export_images" = true ]; then
        export_arm_images
    fi
    
    # Show summary
    echo
    echo "📋 Built Images:"
    docker images | grep "$IMAGE_NAME" | head -10
    
    echo
    echo "🚀 Next Steps:"
    if [ "$build_amd64" = true ]; then
        echo "• Test locally: ./deploy-to-pi.sh deploy"
        echo "• Test ARM emulation: ./deploy-to-pi.sh test-arm"
    fi
    if [ "$build_arm" = true ]; then
        echo "• Deploy to Pi: ./deploy-to-pi.sh deploy-remote pi@PI_IP"
        if [ "$export_images" = false ]; then
            echo "• Export for Pi: ./deploy-to-pi.sh export"
        fi
    fi
    
    success "MediaMTX container build completed successfully!"
    
    echo
    echo "📝 Container Details:"
    echo "• Base: Alpine Linux 3.18 (lightweight and secure)"
    echo "• MediaMTX: v1.12.3 (Go-based media server)"
    echo "• CamillaDSP: Disabled (requires glibc, available for future enhancement)"
    echo "• Size: ~220MB (vs ~500MB for Python approach)"
    echo "• Startup: ~3 seconds (vs ~30 seconds for Python approach)"
}

main "$@"