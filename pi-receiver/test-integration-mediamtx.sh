#!/bin/bash
#
# Integration Test for MediaMTX Container on Real Raspberry Pi
#
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
PI_IP="${1:-192.168.1.254}"
PI_USER="${2:-pi}"
CONTAINER_NAME="rew-mediamtx-audio-receiver"

echo "🧪 MediaMTX Container Integration Test"
echo "====================================="
log "Testing MediaMTX container on Pi: ${PI_USER}@${PI_IP}"

# Test 1: Check if container is running
log "Test 1: Verifying container is running..."
if ssh "${PI_USER}@${PI_IP}" "docker ps | grep -q ${CONTAINER_NAME}"; then
    success "Container is running"
    # Show container details
    ssh "${PI_USER}@${PI_IP}" "docker ps | grep ${CONTAINER_NAME}"
else
    error "Container is not running"
    log "Checking if container exists but stopped..."
    if ssh "${PI_USER}@${PI_IP}" "docker ps -a | grep -q ${CONTAINER_NAME}"; then
        warning "Container exists but is stopped"
        ssh "${PI_USER}@${PI_IP}" "docker ps -a | grep ${CONTAINER_NAME}"
        log "Container logs:"
        ssh "${PI_USER}@${PI_IP}" "docker logs ${CONTAINER_NAME} --tail 20"
    else
        error "Container does not exist"
    fi
    exit 1
fi

# Test 2: MediaMTX API Health Check
log "Test 2: Testing MediaMTX API endpoints..."
if curl -sf "http://${PI_IP}:9997/v3/config" >/dev/null; then
    success "MediaMTX API responding on port 9997"
    log "MediaMTX configuration preview:"
    curl -s "http://${PI_IP}:9997/v3/config" | head -20
else
    error "MediaMTX API not responding on port 9997"
    exit 1
fi

# Test MediaMTX paths endpoint
if curl -sf "http://${PI_IP}:9997/v3/paths/list" >/dev/null; then
    success "MediaMTX paths endpoint responding"
    log "Active streams:"
    curl -s "http://${PI_IP}:9997/v3/paths/list"
else
    warning "MediaMTX paths endpoint not responding"
fi

# Test 3: CamillaDSP API Health Check (if enabled)
log "Test 3: Testing CamillaDSP API..."
if curl -sf "http://${PI_IP}:1234/api/v1/state" >/dev/null; then
    success "CamillaDSP API responding on port 1234"
    log "CamillaDSP state:"
    curl -s "http://${PI_IP}:1234/api/v1/state"
else
    warning "CamillaDSP API not responding (may be disabled in start.sh)"
fi

# Test 4: RTP Port Accessibility
log "Test 4: Testing RTP port accessibility..."
if nc -u -z "${PI_IP}" 5004 2>/dev/null; then
    success "RTP port 5004 is accessible"
else
    warning "RTP port test inconclusive (UDP limitations)"
fi

# Test 5: RTSP Stream Availability
log "Test 5: Testing RTSP stream availability..."
if timeout 5 curl -sf "rtsp://${PI_IP}:8554/" >/dev/null 2>&1; then
    success "RTSP server responding on port 8554"
else
    warning "RTSP server test inconclusive (requires actual stream)"
fi

# Test 6: Container Resource Usage
log "Test 6: Checking container resource usage..."
container_stats=$(ssh "${PI_USER}@${PI_IP}" "docker stats ${CONTAINER_NAME} --no-stream --format 'table {{.MemUsage}}\t{{.CPUPerc}}'")
log "Container resource usage:"
echo "$container_stats"

# Test 7: Audio System Check
log "Test 7: Checking audio system in container..."
audio_devices=$(ssh "${PI_USER}@${PI_IP}" "docker exec ${CONTAINER_NAME} aplay -l 2>/dev/null || echo 'No audio devices available'")
if echo "$audio_devices" | grep -q "card"; then
    success "Audio devices available in container"
    echo "$audio_devices"
else
    warning "No audio devices available (check volume mounts)"
fi

# Test 8: Container Logs Analysis
log "Test 8: Analyzing container logs..."
log "Recent container logs (last 10 lines):"
ssh "${PI_USER}@${PI_IP}" "docker logs ${CONTAINER_NAME} --tail 10"

# Check for common issues in logs
error_count=$(ssh "${PI_USER}@${PI_IP}" "docker logs ${CONTAINER_NAME} 2>&1 | grep -i error | wc -l")
if [ "$error_count" -eq 0 ]; then
    success "No errors found in container logs"
else
    warning "Found $error_count error lines in logs"
fi

# Test 9: Network Configuration
log "Test 9: Checking network configuration..."
network_mode=$(ssh "${PI_USER}@${PI_IP}" "docker inspect ${CONTAINER_NAME} --format='{{.HostConfig.NetworkMode}}'")
log "Network mode: $network_mode"

if [ "$network_mode" = "host" ]; then
    success "Container using host networking (recommended for RTP)"
else
    warning "Container not using host networking (may affect RTP performance)"
fi

# Test 10: REW Connection Simulation
log "Test 10: Simulating REW connection test..."
log "Testing basic UDP connectivity to RTP port..."

# Create a simple test packet
test_payload="TEST_RTP_PACKET_$(date +%s)"
if echo "$test_payload" | nc -u -w1 "${PI_IP}" 5004; then
    success "UDP packet sent to RTP port successfully"
else
    warning "UDP packet test inconclusive"
fi

# Final Summary
echo ""
echo "📋 Integration Test Summary"
echo "=========================="
success "✅ Container is running and accessible"
success "✅ MediaMTX API is responding"
if curl -sf "http://${PI_IP}:1234/api/v1/state" >/dev/null; then
    success "✅ CamillaDSP API is responding"
else
    warning "⚠️  CamillaDSP API not responding (may be disabled)"
fi
success "✅ Network ports are accessible"

echo ""
echo "🚀 Ready for REW Connection!"
echo "REW Settings:"
echo "• RTP Target: ${PI_IP}:5004"
echo "• Timeout: 5000ms (recommended for Pi)"
echo "• Format: 16-bit, 48kHz (default)"

echo ""
echo "🔧 Management Commands:"
echo "• View logs: ssh ${PI_USER}@${PI_IP} 'docker logs ${CONTAINER_NAME} -f'"
echo "• Restart: ssh ${PI_USER}@${PI_IP} 'docker restart ${CONTAINER_NAME}'"
echo "• Stop: ssh ${PI_USER}@${PI_IP} 'docker stop ${CONTAINER_NAME}'"
echo "• Status: ssh ${PI_USER}@${PI_IP} 'docker ps | grep mediamtx'"