#!/bin/bash

# Comprehensive Test Suite for REW Loopback Script
# Tests device creation, management, and edge cases

set -e

# Test configuration
SCRIPT_PATH="./rew-loopback"
TEST_RESULTS_FILE="/tmp/rew-loopback-test-results.txt"
BACKUP_CONFIG_FILE=""
ORIGINAL_DEVICES=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    echo "FAIL: $1" >> "$TEST_RESULTS_FILE"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Utility functions
count_rew_devices() {
    pactl list short sinks | grep -i "rew" | wc -l || echo "0"
}

device_exists() {
    local device_name="$1"
    pactl list short sinks | grep -q "^[0-9]*[[:space:]]*$device_name[[:space:]]"
}

get_device_description() {
    local device_name="$1"
    pactl list sinks | grep -A 20 "Name: $device_name" | grep "device.description" | cut -d'"' -f2 || echo ""
}

wait_for_pulseaudio() {
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if pactl info &> /dev/null; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# Test setup and teardown
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Check if PulseAudio is available
    if ! command -v pactl &> /dev/null; then
        echo "ERROR: pactl command not found. PulseAudio is required for testing."
        exit 1
    fi
    
    if ! wait_for_pulseaudio; then
        echo "ERROR: PulseAudio server is not running or not accessible."
        exit 1
    fi
    
    # Check if script exists and is executable
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "ERROR: REW loopback script not found at $SCRIPT_PATH"
        exit 1
    fi
    
    if [ ! -x "$SCRIPT_PATH" ]; then
        echo "ERROR: REW loopback script is not executable"
        exit 1
    fi
    
    # Backup existing config if present
    if [ -f "$HOME/.rew-loopback" ]; then
        BACKUP_CONFIG_FILE="$HOME/.rew-loopback.backup-$(date +%s)"
        cp "$HOME/.rew-loopback" "$BACKUP_CONFIG_FILE"
        log_info "Backed up existing config to $BACKUP_CONFIG_FILE"
    fi
    
    # Record original device state
    ORIGINAL_DEVICES=$(count_rew_devices)
    log_info "Original REW devices count: $ORIGINAL_DEVICES"
    
    # Clean up any existing REW devices
    log_info "Cleaning up any existing REW devices..."
    "$SCRIPT_PATH" cleanup &>/dev/null || true
    
    # Initialize test results file
    echo "REW Loopback Test Results - $(date)" > "$TEST_RESULTS_FILE"
    echo "======================================" >> "$TEST_RESULTS_FILE"
    
    log_info "Test environment ready"
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    # Clean up any REW devices created during testing
    "$SCRIPT_PATH" cleanup &>/dev/null || true
    
    # Restore original config if we backed it up
    if [ -n "$BACKUP_CONFIG_FILE" ] && [ -f "$BACKUP_CONFIG_FILE" ]; then
        mv "$BACKUP_CONFIG_FILE" "$HOME/.rew-loopback"
        log_info "Restored original config"
    fi
    
    log_info "Test cleanup complete"
}

# Individual test functions
test_script_help() {
    log_test "Testing help command..."
    ((TESTS_RUN++))
    
    if "$SCRIPT_PATH" help &>/dev/null; then
        log_pass "Help command executes successfully"
    else
        log_fail "Help command failed"
        return 1
    fi
    
    # Test that help output contains expected content
    local help_output
    help_output=$("$SCRIPT_PATH" help 2>&1)
    
    if echo "$help_output" | grep -q "create.*Create REW virtual audio device"; then
        log_pass "Help output contains create command description"
    else
        log_fail "Help output missing create command description"
        return 1
    fi
    
    if echo "$help_output" | grep -q "remove.*Remove REW virtual audio device"; then
        log_pass "Help output contains remove command description"
    else
        log_fail "Help output missing remove command description"
        return 1
    fi
}

test_device_creation() {
    log_test "Testing device creation..."
    ((TESTS_RUN++))
    
    # Ensure we start clean
    "$SCRIPT_PATH" cleanup &>/dev/null || true
    
    local initial_count=$(count_rew_devices)
    
    # Test device creation
    if "$SCRIPT_PATH" create &>/dev/null; then
        log_pass "Device creation command succeeded"
    else
        log_fail "Device creation command failed"
        return 1
    fi
    
    # Verify device was created
    local final_count=$(count_rew_devices)
    if [ "$final_count" -gt "$initial_count" ]; then
        log_pass "Device count increased after creation ($initial_count -> $final_count)"
    else
        log_fail "Device count did not increase after creation"
        return 1
    fi
    
    # Verify specific device exists
    if device_exists "REW_Network_Audio_Bridge"; then
        log_pass "REW_Network_Audio_Bridge device exists"
    else
        log_fail "REW_Network_Audio_Bridge device not found"
        return 1
    fi
    
    # Verify device has correct description
    local description
    description=$(get_device_description "REW_Network_Audio_Bridge")
    if [ "$description" = "REW Network Audio Bridge" ]; then
        log_pass "Device has correct description: '$description'"
    else
        log_fail "Device has incorrect description: '$description' (expected: 'REW Network Audio Bridge')"
        return 1
    fi
    
    # Verify monitor source exists
    if pactl list short sources | grep -q "REW_Network_Audio_Bridge.monitor"; then
        log_pass "Monitor source exists"
    else
        log_fail "Monitor source not found"
        return 1
    fi
    
    # Verify config file was created
    if [ -f "$HOME/.rew-loopback" ]; then
        log_pass "Configuration file was created"
    else
        log_fail "Configuration file was not created"
        return 1
    fi
}

test_device_status() {
    log_test "Testing device status reporting..."
    ((TESTS_RUN++))
    
    # Test status when device exists
    if "$SCRIPT_PATH" status &>/dev/null; then
        log_pass "Status command executes successfully with existing device"
    else
        log_fail "Status command failed with existing device"
        return 1
    fi
    
    # Check status output content
    local status_output
    status_output=$("$SCRIPT_PATH" status 2>&1)
    
    if echo "$status_output" | grep -q "REW Virtual Audio Device Status"; then
        log_pass "Status output contains header"
    else
        log_fail "Status output missing header"
        return 1
    fi
    
    if echo "$status_output" | grep -q "Device Name: REW_Network_Audio_Bridge"; then
        log_pass "Status output contains device name"
    else
        log_fail "Status output missing device name"
        return 1
    fi
}

test_duplicate_creation_prevention() {
    log_test "Testing duplicate device creation prevention..."
    ((TESTS_RUN++))
    
    # Device should already exist from previous test
    local initial_count=$(count_rew_devices)
    
    # Try to create again - should be prevented
    if "$SCRIPT_PATH" create &>/dev/null; then
        # This should succeed but not create a new device
        local final_count=$(count_rew_devices)
        
        if [ "$final_count" -eq "$initial_count" ]; then
            log_pass "Duplicate creation properly prevented (device count unchanged: $initial_count)"
        else
            log_fail "Duplicate creation was not prevented (count: $initial_count -> $final_count)"
            return 1
        fi
    else
        log_fail "Create command failed when device already exists"
        return 1
    fi
}

test_device_listing() {
    log_test "Testing device listing..."
    ((TESTS_RUN++))
    
    if "$SCRIPT_PATH" list &>/dev/null; then
        log_pass "List command executes successfully"
    else
        log_fail "List command failed"
        return 1
    fi
    
    # Check that our device appears in the listing
    local list_output
    list_output=$("$SCRIPT_PATH" list 2>&1)
    
    if echo "$list_output" | grep -q "REW_Network_Audio_Bridge.*REW Virtual Device"; then
        log_pass "REW device appears in listing with correct label"
    else
        log_fail "REW device not properly labeled in listing"
        return 1
    fi
    
    if echo "$list_output" | grep -q "REW_Network_Audio_Bridge.monitor.*REW Monitor"; then
        log_pass "REW monitor source appears in listing"
    else
        log_fail "REW monitor source not found in listing"
        return 1
    fi
}

test_device_removal() {
    log_test "Testing device removal..."
    ((TESTS_RUN++))
    
    local initial_count=$(count_rew_devices)
    
    # Test device removal
    if "$SCRIPT_PATH" remove &>/dev/null; then
        log_pass "Device removal command succeeded"
    else
        log_fail "Device removal command failed"
        return 1
    fi
    
    # Verify device was removed
    local final_count=$(count_rew_devices)
    if [ "$final_count" -lt "$initial_count" ]; then
        log_pass "Device count decreased after removal ($initial_count -> $final_count)"
    else
        log_fail "Device count did not decrease after removal"
        return 1
    fi
    
    # Verify specific device is gone
    if ! device_exists "REW_Network_Audio_Bridge"; then
        log_pass "REW_Network_Audio_Bridge device was removed"
    else
        log_fail "REW_Network_Audio_Bridge device still exists"
        return 1
    fi
    
    # Verify config file was cleaned up
    if [ ! -f "$HOME/.rew-loopback" ] || [ ! -s "$HOME/.rew-loopback" ]; then
        log_pass "Configuration file was cleaned up"
    else
        log_fail "Configuration file still contains data"
        return 1
    fi
}

test_restart_functionality() {
    log_test "Testing device restart functionality..."
    ((TESTS_RUN++))
    
    # Create device first
    "$SCRIPT_PATH" create &>/dev/null
    local initial_count=$(count_rew_devices)
    
    # Test restart
    if "$SCRIPT_PATH" restart &>/dev/null; then
        log_pass "Restart command succeeded"
    else
        log_fail "Restart command failed"
        return 1
    fi
    
    # Verify device still exists after restart
    local final_count=$(count_rew_devices)
    if [ "$final_count" -eq "$initial_count" ] && device_exists "REW_Network_Audio_Bridge"; then
        log_pass "Device exists after restart with same count"
    else
        log_fail "Device state incorrect after restart (count: $initial_count -> $final_count)"
        return 1
    fi
}

test_comprehensive_cleanup() {
    log_test "Testing comprehensive cleanup..."
    ((TESTS_RUN++))
    
    # Create device first
    "$SCRIPT_PATH" create &>/dev/null
    
    # Test comprehensive cleanup
    if "$SCRIPT_PATH" cleanup &>/dev/null; then
        log_pass "Cleanup command succeeded"
    else
        log_fail "Cleanup command failed"
        return 1
    fi
    
    # Verify all REW devices are gone
    local rew_count=$(count_rew_devices)
    if [ "$rew_count" -eq 0 ]; then
        log_pass "All REW devices cleaned up"
    else
        log_fail "REW devices still exist after cleanup (count: $rew_count)"
        return 1
    fi
}

test_error_conditions() {
    log_test "Testing error condition handling..."
    ((TESTS_RUN++))
    
    # Test invalid command
    if ! "$SCRIPT_PATH" invalid_command &>/dev/null; then
        log_pass "Invalid command properly rejected"
    else
        log_fail "Invalid command was not rejected"
        return 1
    fi
    
    # Test status when no device exists
    if "$SCRIPT_PATH" status &>/dev/null; then
        log_pass "Status command handles missing device gracefully"
    else
        log_fail "Status command failed when device missing"
        return 1
    fi
    
    # Test removal when no device exists
    if "$SCRIPT_PATH" remove &>/dev/null; then
        log_pass "Remove command handles missing device gracefully"
    else
        log_fail "Remove command failed when device missing"
        return 1
    fi
}

# Main test execution
run_all_tests() {
    log_info "Starting REW Loopback Script Test Suite"
    log_info "========================================"
    
    # Run individual tests
    test_script_help
    test_device_creation
    test_device_status
    test_duplicate_creation_prevention
    test_device_listing
    test_device_removal
    test_restart_functionality
    test_comprehensive_cleanup
    test_error_conditions
    
    # Print summary
    echo
    log_info "Test Results Summary"
    log_info "==================="
    log_info "Tests Run: $TESTS_RUN"
    log_pass "Tests Passed: $TESTS_PASSED"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        log_fail "Tests Failed: $TESTS_FAILED"
        echo
        echo "Failed tests details:"
        cat "$TEST_RESULTS_FILE"
    else
        log_pass "All tests passed! ✨"
    fi
    
    echo
    log_info "Detailed results saved to: $TEST_RESULTS_FILE"
    
    return $TESTS_FAILED
}

# Script execution
main() {
    # Ensure we're in the right directory
    cd "$(dirname "$0")"
    
    # Set up test environment
    setup_test_environment
    
    # Handle cleanup on exit
    trap cleanup_test_environment EXIT
    
    # Run tests
    if run_all_tests; then
        echo
        log_pass "All tests completed successfully!"
        exit 0
    else
        echo
        log_fail "Some tests failed. Check the output above for details."
        exit 1
    fi
}

# Show usage if requested
if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
REW Loopback Test Suite

Usage: $0

This script runs comprehensive tests on the rew-loopback script to ensure:
• Device creation works correctly with proper naming
• Duplicate device detection prevents conflicts
• Device removal cleans up properly
• Status reporting is accurate
• Error conditions are handled gracefully

The test suite will:
1. Backup any existing REW loopback configuration
2. Run all tests in isolation
3. Clean up test artifacts
4. Restore original configuration

Requirements:
• PulseAudio must be running
• rew-loopback script must be in the current directory
• User must have permissions to create/remove audio devices

Test results are saved to: $TEST_RESULTS_FILE
EOF
    exit 0
fi

# Run main function
main "$@"