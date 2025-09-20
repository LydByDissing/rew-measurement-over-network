#!/bin/bash
#
# Validate MediaMTX and CamillaDSP configurations
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[VALIDATE]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

log "🔍 Validating configurations..."

# Test MediaMTX configuration
log "Testing MediaMTX configuration..."
if ./binaries/mediamtx --help >/dev/null 2>&1; then
    success "MediaMTX binary is functional"
else
    error "MediaMTX binary test failed"
fi

# Test CamillaDSP configuration
log "Testing CamillaDSP configuration..."
if ./binaries/camilladsp --help >/dev/null 2>&1; then
    success "CamillaDSP binary is functional"
else
    error "CamillaDSP binary test failed"
fi

# Validate YAML syntax
log "Validating MediaMTX YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('mediamtx.yml'))" 2>/dev/null; then
    success "MediaMTX YAML is valid"
else
    error "MediaMTX YAML syntax error"
fi

log "Validating CamillaDSP YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('camilladsp.yml'))" 2>/dev/null; then
    success "CamillaDSP YAML is valid"
else
    error "CamillaDSP YAML syntax error"
fi

success "✅ Configuration validation complete"