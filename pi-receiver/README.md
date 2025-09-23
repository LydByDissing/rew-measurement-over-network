# REW Audio Receiver

A simplified audio receiver system for REW measurements using CamillaDSP and RTP/UDP to ALSA bridges.

## Overview

This system provides audio processing capabilities using CamillaDSP with RTP and UDP bridges that receive audio streams and forward them to ALSA devices. It's designed to work with REW (Room EQ Wizard) for acoustic measurements.

## Architecture

```
RTP/UDP Audio Stream → Bridge Script → ALSA Loopback → CamillaDSP → Audio Output Device
```

## Components

### Core Components
- **CamillaDSP**: High-quality audio DSP processing
- **RTP Bridge**: Receives RTP audio streams (`rtp-to-alsa.sh`)
- **UDP Bridge**: Receives UDP audio streams (`udp-to-alsa.sh`)
- **ALSA Loopback**: Virtual audio device for inter-process audio routing

### Configuration Files
- `camilladsp.yml`: CamillaDSP configuration
- `camilladsp.service`: Systemd service for CamillaDSP
- `udp-bridge.service`: Systemd service for UDP bridge

## Quick Start

### 1. Installation

```bash
cd pi-receiver
sudo ./install.sh
```

This will:
- Install CamillaDSP binary and configuration
- Install RTP and UDP bridge scripts
- Set up systemd services
- Configure ALSA loopback device

### 2. Start Audio Bridges

**RTP Bridge (for RTP audio streams):**
```bash
# Default port 8000
/home/pi/rew-receiver/rtp-to-alsa.sh

# Custom port
/home/pi/rew-receiver/rtp-to-alsa.sh --port 5004
```

**UDP Bridge (for UDP audio streams):**
```bash
# Default port 8000
/home/pi/rew-receiver/udp-to-alsa.sh

# Custom port
/home/pi/rew-receiver/udp-to-alsa.sh --port 8001
```

### 3. Check Status

```bash
# Check CamillaDSP service
sudo systemctl status camilladsp

# View logs
sudo journalctl -u camilladsp -f

# Test CamillaDSP API
curl http://localhost:1234/api/config
```

## Configuration

### Audio Device Configuration

Edit `/home/pi/rew-receiver/camilladsp.yml` to configure your audio output device:

```yaml
devices:
  capture:
    type: Alsa
    channels: 2
    device: "plughw:CARD=Loopback,DEV=1"  # Input from bridge
    format: S16LE
  playback:
    type: Alsa
    channels: 2
    device: "hw:CARD=sndrpimerusamp"  # Your audio output device
    format: S32LE
```

### ALSA Loopback Setup

Ensure ALSA loopback module is loaded:
```bash
sudo modprobe snd-aloop
echo 'snd-aloop' | sudo tee -a /etc/modules
```

## Usage

### Basic Workflow

1. **Start CamillaDSP** (should start automatically via systemd)
2. **Start appropriate bridge script** (RTP or UDP)
3. **Send audio to the bridge port** from your audio source
4. **Audio flows through the pipeline**: Bridge → ALSA Loopback → CamillaDSP → Audio Output

### REW Integration

For REW measurements:
1. Configure REW to send RTP audio to your Pi's IP on port 8000
2. Start the RTP bridge: `/home/pi/rew-receiver/rtp-to-alsa.sh --port 8000`
3. CamillaDSP will process and output the audio to your configured device

## API Access

- **CamillaDSP API**: `http://pi-ip:1234`
  - Configuration: `/api/config`
  - Status: `/api/status`

## Management Commands

```bash
# Service management
sudo systemctl start camilladsp
sudo systemctl stop camilladsp
sudo systemctl restart camilladsp

# View logs
sudo journalctl -u camilladsp -f

# Test audio device
aplay -l
speaker-test -c 2 -r 48000 -D hw:CARD=sndrpimerusamp
```

## Testing

### Test Audio Pipeline
```bash
# Test ALSA loopback
aplay -D plughw:CARD=Loopback,DEV=0 /usr/share/sounds/alsa/Front_Left.wav

# Test CamillaDSP
curl http://localhost:1234/api/config

# Test bridge scripts
./rtp-to-alsa.sh --help
./udp-to-alsa.sh --help
```

## Deployment

### Remote Pi Deployment
```bash
./deploy-to-pi.sh deploy pi@your-pi-ip
```

### Local Installation
```bash
./deploy-to-pi.sh install
```

## Troubleshooting

### Common Issues

1. **No audio output**: Check audio device configuration in `camilladsp.yml`
2. **Bridge not receiving**: Verify network connectivity and port availability
3. **ALSA errors**: Ensure loopback module is loaded (`lsmod | grep snd_aloop`)
4. **Service issues**: Check logs with `journalctl -u camilladsp -f`

### Debug Commands
```bash
# Check audio devices
aplay -l

# Check ALSA loopback
cat /proc/asound/cards

# Test network ports
netstat -an | grep :8000

# Check processes
pgrep -f camilladsp
pgrep -f rtp-to-alsa
```

## Files Structure

```
pi-receiver/
├── camilladsp                    # CamillaDSP binary
├── camilladsp.yml               # CamillaDSP configuration
├── camilladsp.service          # Systemd service
├── rtp-to-alsa.sh             # RTP bridge script
├── udp-to-alsa.sh             # UDP bridge script
├── udp-bridge.service         # UDP bridge systemd service
├── deploy-to-pi.sh            # Deployment script
├── install.sh                 # Installation script
├── start.sh                   # Manual start script
└── test-audio.sh              # Audio testing utility
```

## Requirements

- Raspberry Pi (or compatible ARM device)
- ALSA audio system
- FFmpeg (for bridge scripts)
- Network connectivity for audio streaming

## License

This project is part of the REW measurement system and follows the same licensing terms.
