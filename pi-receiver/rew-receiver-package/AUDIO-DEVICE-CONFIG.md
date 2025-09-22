# Audio Device Configuration for REW MediaMTX Audio Receiver

This guide explains how to configure specific audio devices, including the `snd_rpi_merus_amp`, for use with the REW MediaMTX Audio Receiver.

## Overview

The system uses CamillaDSP for audio processing, which can be configured to use any ALSA-compatible audio device. This setup allows you to:

1. Configure a specific audio device (like `hw:CARD=sndrpimerusamp`)
2. Validate audio playback through the processing workflow
3. Test with speaker-test utilities before integrating with MediaMTX

## Quick Start for Merus Amplifier

```bash
# Run the automated Merus amplifier test
./test-merus-amp.sh
```

This script will:
1. Configure CamillaDSP for the `hw:CARD=sndrpimerusamp` device
2. Run audio validation tests
3. Prompt for manual validation of audio output

## Manual Configuration

### 1. Configure Audio Device

```bash
# Configure for Merus amplifier
./configure-audio-device.sh -d "hw:CARD=sndrpimerusamp"

# Configure for other devices
./configure-audio-device.sh -d hw:1,0
./configure-audio-device.sh -d plughw:0,0
```

### 2. Validate Audio Device

```bash
# Test the configured device
./validate-audio-device.sh -d "hw:CARD=sndrpimerusamp"

# Test with custom parameters
./validate-audio-device.sh -d "hw:CARD=sndrpimerusamp" -f 440 -t 5
```

### 3. Manual Testing

```bash
# Direct speaker test (S32_LE format required for Merus amplifier)
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1 -p 3000

# Test CamillaDSP configuration
./camilladsp -c camilladsp.yml
```

## Common Audio Devices

| Device Name | Description |
|-------------|-------------|
| `hw:CARD=sndrpimerusamp` | Raspberry Pi Merus amplifier (requires S32_LE format) |
| `hw:0,0` | Default hardware device |
| `hw:1,0` | Secondary hardware device |
| `plughw:0,0` | ALSA plug layer (with format conversion) |
| `default` | ALSA default device |

## Configuration Files

- `camilladsp.yml.template` - Template with `${AUDIO_DEVICE}` placeholder
- `camilladsp.yml` - Generated configuration file
- `mediamtx.yml` - MediaMTX server configuration

## Troubleshooting

### Device Not Found

```bash
# List available ALSA devices
aplay -l
cat /proc/asound/cards

# Check kernel modules
lsmod | grep snd
```

### Audio Not Working

```bash
# Test different devices
./validate-audio-device.sh -d hw:0,0
./validate-audio-device.sh -d hw:1,0
./validate-audio-device.sh -d plughw:0,0

# Check ALSA configuration
alsamixer
amixer sget Master
```

### Permission Issues

```bash
# Add user to audio group
sudo usermod -a -G audio $USER

# Check device permissions
ls -l /dev/snd/
```

## Integration with MediaMTX

Once audio validation is successful:

1. **Start CamillaDSP**: `camilladsp -p 1234 camilladsp.yml`
2. **Start MediaMTX**: `mediamtx mediamtx.yml`
3. **Test the pipeline**: Send RTP audio to port 5004

The audio flow will be:
```
RTP Input (port 5004) → MediaMTX → CamillaDSP → Audio Device (hw:CARD=sndrpimerusamp)
```

## Script Reference

| Script | Purpose |
|--------|---------|
| `configure-audio-device.sh` | Generate CamillaDSP config for specific device |
| `validate-audio-device.sh` | Test audio device with speaker-test |
| `test-merus-amp.sh` | Complete workflow for Merus amplifier |

## Example Workflow

```bash
# 1. Configure for Merus amplifier
./configure-audio-device.sh -d "hw:CARD=sndrpimerusamp"

# 2. Validate configuration
./validate-audio-device.sh -d "hw:CARD=sndrpimerusamp"

# 3. Start services (if validation successful)
./camilladsp -p 1234 camilladsp.yml &
./mediamtx mediamtx.yml &

# 4. Test RTP streaming to port 5004
```

Manual validation is required at step 2 - you must confirm that you can hear the test tone through your audio output.
