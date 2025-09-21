# MediaMTX → CamillaDSP → Merus Amplifier Pipeline Validation

This guide walks through validating the complete audio processing pipeline from RTP input to Merus amplifier output.

## 🎯 Pipeline Overview

```
RTP Input (port 5004) → MediaMTX → CamillaDSP → hw:CARD=sndrpimerusamp (S32_LE)
```

## ✅ Prerequisites

1. **Hardware**: Raspberry Pi with Merus amplifier connected
2. **Configuration**: CamillaDSP configured for `hw:CARD=sndrpimerusamp` with S32_LE format
3. **Network**: Pi accessible on network for RTP streaming

## 🚀 Validation Steps

### Step 1: Verify Audio Device Configuration

```bash
# Test the Merus amplifier directly
./test-merus-amp.sh

# Should output:
# ✅ CamillaDSP configured for Merus amplifier
# ✅ Audio validation successful!
```

### Step 2: Test Complete Pipeline

```bash
# Start MediaMTX and CamillaDSP services
./test-full-pipeline.sh
```

This script will:
- ✅ Configure CamillaDSP for the Merus amplifier
- ✅ Start CamillaDSP on port 1234
- ✅ Start MediaMTX on port 9997
- ✅ Test direct audio to verify the chain
- ✅ Wait for RTP input

Expected output:
```
✅ CamillaDSP started successfully
✅ CamillaDSP API responding
✅ MediaMTX started successfully
✅ MediaMTX API responding
✅ Direct audio test completed
🌐 Pipeline is ready for RTP input!
```

### Step 3: Test RTP Streaming

#### Option A: Local Test (using ffmpeg)

```bash
# Generate test RTP stream (in a new terminal)
./test-rtp-stream.sh

# Or test to remote Pi
./test-rtp-stream.sh 192.168.1.100
```

#### Option B: Test with REW

1. **Configure REW Output**:
   - Generator → Preferences → Output Device: `Network/RTP`
   - RTP Target: `PI_IP_ADDRESS:5004`

2. **Test Audio**:
   - Open REW Signal Generator
   - Play a test tone
   - Should hear audio through Merus amplifier

## 🔧 Service Management

### Manual Service Control

```bash
# Start CamillaDSP
camilladsp -p 1234 camilladsp.yml &

# Start MediaMTX
mediamtx mediamtx.yml &

# Stop services
pkill -f camilladsp
pkill -f mediamtx
```

### Check Service Status

```bash
# Check if services are running
pgrep -f mediamtx     # Should return PID
pgrep -f camilladsp   # Should return PID

# Check API endpoints
curl http://localhost:9997/v3/config    # MediaMTX API
curl http://localhost:1234/api/v1/state # CamillaDSP API
```

## 🐛 Troubleshooting

### No Audio Output

1. **Check audio device**:
   ```bash
   speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1
   ```

2. **Check CamillaDSP config**:
   ```bash
   grep -A 4 "playback:" camilladsp.yml
   # Should show: device: "hw:CARD=sndrpimerusamp", format: S32LE
   ```

### Services Won't Start

1. **Check ports**:
   ```bash
   sudo netstat -tulpn | grep -E "(1234|9997|5004)"
   ```

2. **Check logs**:
   ```bash
   # If using systemd
   sudo journalctl -u mediamtx -f
   sudo journalctl -u camilladsp -f
   ```

### RTP Stream Issues

1. **Check network connectivity**:
   ```bash
   ping PI_IP_ADDRESS
   ```

2. **Check firewall**:
   ```bash
   # Ensure UDP port 5004 is open
   sudo ufw allow 5004/udp
   ```

3. **Test with netcat**:
   ```bash
   # On sender: echo "test" | nc -u PI_IP 5004
   # On Pi: nc -l -u 5004
   ```

## 📊 Expected Performance

- **Latency**: < 50ms end-to-end
- **Sample Rate**: 48000 Hz
- **Bit Depth**: 32-bit (S32_LE)
- **Channels**: 2 (stereo)
- **Format**: Uncompressed PCM via RTP

## 🎵 REW Integration

### REW Output Configuration

1. **Generator Tab**:
   - Output Device: `Network/RTP`
   - Sample Rate: `48000 Hz`
   - Target: `PI_IP:5004`

2. **Measurement**:
   - Input Device: (your measurement mic)
   - Output Device: `Network/RTP`
   - Ensure generator and measurement use same target

### Testing REW Connection

1. Start the pipeline: `./test-full-pipeline.sh`
2. Configure REW as above
3. Use REW Signal Generator to play a tone
4. Should hear audio through Merus amplifier
5. Ready for measurements!

## 🏁 Success Criteria

✅ **Complete validation successful when**:
- Direct audio test plays through Merus amplifier
- MediaMTX and CamillaDSP APIs respond
- RTP test stream produces audio output
- REW can successfully stream audio to the Pi
- Audio quality is clear without distortion

The pipeline is then ready for Room EQ Wizard measurements!
