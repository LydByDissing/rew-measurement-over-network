# Dependency Management Guide

This guide explains how to manage dependencies for the REW MediaMTX Audio Receiver on Raspberry Pi.

## Quick Start

After deploying to Pi, check and install dependencies:

```bash
# SSH to your Pi
ssh pi@192.168.1.254

# Navigate to the installation directory
cd /home/pi/rew-receiver

# Check what dependencies are missing
./check-dependencies.sh

# Install missing dependencies
./install-dependencies.sh
```

## Dependency Tools

### `check-dependencies.sh`
- **Purpose**: Check which dependencies are available/missing
- **Usage**: `./check-dependencies.sh`
- **Output**: Shows status of critical and optional dependencies
- **Safe**: Read-only operation, no system modifications

### `install-dependencies.sh`
- **Purpose**: Install missing system packages
- **Usage**: `./install-dependencies.sh`
- **Requirements**: Requires `sudo` access for package installation
- **Packages Installed**:
  - `ffmpeg` - RTP stream generation and media processing
  - `alsa-utils` - ALSA audio utilities (aplay, speaker-test)
  - `curl` - API testing and downloads
  - `gettext-base` - Template processing (envsubst)
  - `netcat-openbsd` - Network testing
  - `pulseaudio-utils` - PulseAudio utilities
  - `jq` - JSON processing

## Critical Dependencies

These are required for audio testing and RTP streaming:

| Tool | Purpose | Package |
|------|---------|---------|
| `ffmpeg` | RTP stream generation | `ffmpeg` |
| `aplay` | Audio playback testing | `alsa-utils` |
| `speaker-test` | Direct audio device testing | `alsa-utils` |
| `envsubst` | Configuration templates | `gettext-base` |
| `curl` | API endpoint testing | `curl` |

## Optional Dependencies

These enhance functionality but are not critical:

| Tool | Purpose | Package |
|------|---------|---------|
| `nc` | Network connectivity testing | `netcat-openbsd` |
| `jq` | JSON processing | `jq` |
| `pulseaudio` | PulseAudio utilities | `pulseaudio-utils` |

## Manual Installation

If automatic installation fails, install manually:

```bash
# Update package lists
sudo apt-get update

# Install critical packages
sudo apt-get install -y ffmpeg alsa-utils curl gettext-base

# Install optional packages
sudo apt-get install -y netcat-openbsd jq pulseaudio-utils
```

## Troubleshooting

### FFmpeg Missing
```bash
# Check if universe repository is enabled (Ubuntu)
sudo add-apt-repository universe
sudo apt-get update
sudo apt-get install ffmpeg
```

### ALSA Utils Missing
```bash
sudo apt-get install alsa-utils
```

### Permission Issues
```bash
# Ensure script is executable
chmod +x ./install-dependencies.sh ./check-dependencies.sh

# Run with sudo if needed for package installation
sudo ./install-dependencies.sh
```

## Testing After Installation

Once dependencies are installed:

1. **Test audio device**:
   ```bash
   ./test-merus-amp.sh
   ```

2. **Test full pipeline**:
   ```bash
   ./test-full-pipeline.sh
   ```

3. **Test RTP streaming**:
   ```bash
   ./test-rtp-stream.sh
   ```

## Verification

Verify all dependencies are working:

```bash
# Check dependency status
./check-dependencies.sh

# Test critical tools
ffmpeg -version
aplay -l
speaker-test --help
curl --version
```

## Integration with REW

After dependencies are installed, configure REW to stream RTP audio to:
- **IP**: Your Pi's IP address (e.g., 192.168.1.254)
- **Port**: 5004
- **Protocol**: RTP/UDP
- **Format**: PCM 48kHz 16-bit stereo (will be converted to S32_LE for Merus amp)
