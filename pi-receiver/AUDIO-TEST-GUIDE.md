# Audio Test Utility Guide

The REW Pi Receiver container includes a comprehensive audio test utility to validate the audio chain and troubleshoot configuration issues.

## Quick Start

### Basic Usage

```bash
# Inside the container - run full system test
./test-audio.sh full

# Interactive menu
./test-audio.sh

# Test specific components
./test-audio.sh alsa
./test-audio.sh loopback
./test-audio.sh tone
```

### Docker Exec Usage

```bash
# From host system - run full test in running container
docker exec -it rew-pi-receiver ./test-audio.sh full

# Interactive mode
docker exec -it rew-pi-receiver ./test-audio.sh

# Specific tests
docker exec -it rew-pi-receiver ./test-audio.sh tone
```

## Test Types

### 1. Full System Test (`full` or `all`)
**Recommended for initial validation**

```bash
./test-audio.sh full
```

Runs all audio tests in sequence:
- ALSA system check
- ALSA loopback validation
- Test tone generation
- CamillaDSP integration
- MediaMTX integration

**Expected Output:**
```
✅ All audio tests passed! Audio system is working correctly.
🎵 Your Pi is ready to receive RTP audio streams on port 5004
🔗 Configure REW to send RTP to: 192.168.1.100:5004
```

### 2. ALSA System Test (`alsa`)

Tests basic ALSA audio subsystem:
- Checks for ALSA tools installation
- Lists available audio devices
- Validates default device access
- Loads snd-aloop module if needed

```bash
./test-audio.sh alsa
```

### 3. ALSA Loopback Test (`loopback`)

Specifically tests the ALSA loopback device required for MediaMTX:
- Verifies snd-aloop module is loaded
- Tests `hw:Loopback,0,0` device access
- Suggests alternative device names if needed

```bash
./test-audio.sh loopback
```

### 4. Test Tone Generation (`tone`)

Plays audible test tones to verify audio output:

```bash
# Play 1kHz tone on default device for 3 seconds
./test-audio.sh tone

# Custom device, frequency, and duration
./test-audio.sh tone hw:Loopback,0,0 440 5

# Parameters: [device] [frequency_hz] [duration_seconds]
```

**🔊 You should hear the test tone through connected speakers**

### 5. CamillaDSP Integration (`camilladsp`)

Tests CamillaDSP audio processor integration:
- Validates configuration file
- Checks if CamillaDSP process is running
- Tests API connectivity (if enabled)

```bash
./test-audio.sh camilladsp
```

### 6. MediaMTX Integration (`mediamtx`)

Tests MediaMTX streaming server:
- Verifies MediaMTX process status
- Tests API endpoints
- Checks RTP port 5004 listening
- Validates path configurations

```bash
./test-audio.sh mediamtx
```

### 7. Environment Check (`env`)

Basic container environment validation:
- Docker container detection
- User permissions check
- System capabilities

```bash
./test-audio.sh env
```

## Interactive Mode

Run without arguments for an interactive menu:

```bash
./test-audio.sh
```

```
===== AUDIO TEST UTILITY =====
1) Full System Test (recommended)
2) ALSA System Test
3) ALSA Loopback Test
4) Play Test Tone (default device)
5) Play Test Tone (loopback device)
6) CamillaDSP Integration Test
7) MediaMTX Integration Test
8) Environment Check
9) Exit

Select test (1-9):
```

## Troubleshooting Guide

### Common Issues and Solutions

#### ❌ "No audio devices found"
```bash
# Check if audio devices are available to container
docker run --rm --device /dev/snd rew-pi-receiver ./test-audio.sh alsa
```

**Solutions:**
- Ensure `--device /dev/snd` is used when running container
- Check if audio hardware is available on host system: `aplay -l`

#### ❌ "ALSA Loopback device not found"
```bash
# Load loopback module on host
sudo modprobe snd-aloop

# Or add to boot configuration
echo "snd-aloop" | sudo tee -a /etc/modules-load.d/modules.conf
```

#### ❌ "Default audio device is not accessible"
```bash
# Check container audio permissions
docker run --rm --privileged --device /dev/snd rew-pi-receiver ./test-audio.sh alsa
```

#### ❌ "Tone generation failed"
```bash
# Test with specific ALSA device
./test-audio.sh tone hw:0,0

# Check available devices
aplay -l
```

#### ❌ "MediaMTX API not responding"
```bash
# Check if MediaMTX is running
docker exec rew-pi-receiver pgrep -f mediamtx

# Check port binding
docker exec rew-pi-receiver netstat -tlpn | grep 9997
```

## Integration with Deployment Scripts

### Automatic Testing in Deployment

Add to deployment scripts:

```bash
# After container deployment
echo "🔧 Running audio system validation..."
if docker exec rew-pi-receiver ./test-audio.sh full; then
    echo "✅ Audio system validated successfully"
else
    echo "❌ Audio system validation failed"
    echo "Run 'docker exec -it rew-pi-receiver ./test-audio.sh' for detailed diagnostics"
fi
```

### CI/CD Pipeline Testing

```bash
# Non-interactive testing in pipelines
docker run --rm --device /dev/snd rew-pi-receiver ./test-audio.sh full
```

## Advanced Usage

### Custom Test Configurations

#### Test Different Audio Devices
```bash
# Test specific hardware device
./test-audio.sh tone hw:1,0 1000 3

# Test USB audio device
./test-audio.sh tone plughw:USB,0 440 5
```

#### Debug Audio Chain
```bash
# Step-by-step testing
./test-audio.sh env
./test-audio.sh alsa
./test-audio.sh loopback
./test-audio.sh mediamtx
./test-audio.sh tone hw:Loopback,0,0
```

#### Monitor During Operation
```bash
# Run test while streaming from REW
./test-audio.sh tone hw:Loopback,0,0 440 10 &
# Test tone should play alongside REW audio
```

## Output Examples

### Successful Full Test
```
[AUDIO-TEST] Running full system audio test...
[SUCCESS] ALSA Loopback device found
[SUCCESS] Default audio device is accessible
[SUCCESS] snd-aloop module is loaded
[SUCCESS] Loopback device hw:Loopback,0,0 is accessible
🔊 You should hear a 1000Hz tone for 3 seconds
[SUCCESS] Tone generation completed successfully
[SUCCESS] CamillaDSP configuration is valid
[SUCCESS] CamillaDSP process is running
[SUCCESS] MediaMTX process is running
[SUCCESS] MediaMTX API is responding
[SUCCESS] Port 5004 is listening for RTP streams

===== AUDIO TEST SUMMARY =====
[AUDIO-TEST] Passed: 5/5 tests
[SUCCESS] ✅ All audio tests passed! Audio system is working correctly.

[AUDIO-TEST] 🎵 Your Pi is ready to receive RTP audio streams on port 5004
[AUDIO-TEST] 🔗 Configure REW to send RTP to: 192.168.1.100:5004
```

### Failed Test Example
```
[ERROR] ❌ Some audio tests failed. Check the output above for details.
```

## Help and Support

### Get Help
```bash
./test-audio.sh help
```

### Debug Information
- Container logs: `docker logs rew-pi-receiver`
- Service status: `docker exec rew-pi-receiver ps aux`
- Audio devices: `docker exec rew-pi-receiver aplay -l`
- Network ports: `docker exec rew-pi-receiver netstat -tlpn`

### Report Issues
Include the full output of `./test-audio.sh full` when reporting audio issues.