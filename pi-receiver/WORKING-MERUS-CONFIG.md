# CONFIRMED WORKING Merus Amplifier Configuration

## ✅ Verified Working Command

```bash
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE
```

## 🎯 Key Configuration Details

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Device** | `hw:CARD=sndrpimerusamp` | Direct hardware access |
| **Format** | `S32_LE` | 32-bit signed little-endian (required) |
| **Sample Rate** | `48000` Hz | Standard rate |
| **Channels** | `2` | Stereo |

## 🔧 CamillaDSP Configuration

The template `camilladsp.yml.template` is configured with:

```yaml
playback:
  type: Alsa
  channels: 2
  device: "${AUDIO_DEVICE}"   # Will be: hw:CARD=sndrpimerusamp
  format: S32LE               # Matches speaker-test format
```

## 🚀 Quick Test Commands

```bash
# 1. Test the exact working command
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE

# 2. Configure CamillaDSP for this device
./configure-audio-device.sh -d "hw:CARD=sndrpimerusamp"

# 3. Run full validation workflow
./test-merus-amp.sh

# 4. Quick verification script
./test-confirmed-working.sh
```

## 📝 Key Findings

1. **Device Name**: `hw:CARD=sndrpimerusamp` works (not `usbstream:CARD=sndrpimerusamp`)
2. **Format**: S32_LE is required for the Merus amplifier
3. **Direct Hardware Access**: Using `hw:` prefix for direct ALSA hardware access
4. **Parameter Order**: Format flag `-F S32_LE` at the end of speaker-test command

## 🎵 Audio Flow

```
RTP Input (port 5004) → MediaMTX → CamillaDSP → hw:CARD=sndrpimerusamp (S32_LE)
```

## 🛠️ Troubleshooting

If the working command fails:

1. **Check device availability**: `aplay -l | grep -i merus`
2. **Verify permissions**: User should be in `audio` group
3. **Test alternative formats**: Try S16_LE if S32_LE fails
4. **Check connections**: Ensure Merus amplifier is properly connected

## 📦 Deployment

The configuration is packaged and ready for deployment:

```bash
# Deploy to Pi
./deploy-to-pi.sh package
scp export/rew-receiver-native-*.tar.gz pi@pi-ip:~/
ssh pi@pi-ip 'tar -xzf rew-receiver-native-*.tar.gz && cd rew-receiver-package && ./install.sh'

# On Pi, test the configuration
cd /home/pi/rew-receiver
./test-confirmed-working.sh
./test-merus-amp.sh
```

This configuration has been verified to work with the Merus amplifier hardware.
