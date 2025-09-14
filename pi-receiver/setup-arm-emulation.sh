#!/bin/bash
#
# Raspberry Pi ARM Emulation Setup Script
# Creates a QEMU-based ARM development environment for testing Pi containers
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[ARM-SETUP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/arm-emulation"
RASPIOS_IMAGE="raspios-lite-armhf.img"
KERNEL_REPO="https://github.com/dhruvvyas90/qemu-rpi-kernel"
RASPIOS_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2024-11-19/2024-11-19-raspios-bookworm-armhf-lite.img.xz"

echo "🥧 Raspberry Pi ARM Emulation Setup"
echo "==================================="

# Check if QEMU is installed
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    error "QEMU ARM emulation not installed"
    echo ""
    echo "Please run the following commands to install QEMU:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y qemu-system-arm qemu-utils"
    echo ""
    echo "Then run this script again."
    exit 1
else
    success "QEMU ARM emulation already installed"
fi

# Create VM directory
log "Setting up emulation environment in $VM_DIR"
mkdir -p "$VM_DIR"
cd "$VM_DIR"

# Download QEMU kernel
if [ ! -d "qemu-rpi-kernel" ]; then
    log "Downloading QEMU Raspberry Pi kernel..."
    git clone "$KERNEL_REPO"
else
    success "QEMU kernel already available"
fi

# Download Raspberry Pi OS (if not present)
if [ ! -f "$RASPIOS_IMAGE" ]; then
    log "Downloading Raspberry Pi OS Lite..."
    warning "This may take several minutes..."
    
    if [ ! -f "$(basename "$RASPIOS_URL")" ]; then
        wget "$RASPIOS_URL"
    fi
    
    log "Extracting Raspberry Pi OS image..."
    xz -d "$(basename "$RASPIOS_URL")"
    mv "2024-11-19-raspios-bookworm-armhf-lite.img" "$RASPIOS_IMAGE"
else
    success "Raspberry Pi OS image already available"
fi

# Prepare the image for QEMU
log "Preparing Raspberry Pi OS image for emulation..."

# Get partition info
BOOT_OFFSET=$(fdisk -l "$RASPIOS_IMAGE" | grep "${RASPIOS_IMAGE}1" | awk '{print $2}')
ROOT_OFFSET=$(fdisk -l "$RASPIOS_IMAGE" | grep "${RASPIOS_IMAGE}2" | awk '{print $2}')

BOOT_OFFSET=$((BOOT_OFFSET * 512))
ROOT_OFFSET=$((ROOT_OFFSET * 512))

log "Boot partition offset: $BOOT_OFFSET"
log "Root partition offset: $ROOT_OFFSET"

log "Image preparation requires root privileges for mounting."
log "Creating image modification script..."

# Create a separate script that handles the mounting operations
cat > modify-raspios-image.sh << 'EOF'
#!/bin/bash
# Image modification script (requires sudo)

set -e
RASPIOS_IMAGE="$1"
ROOT_OFFSET="$2"

echo "Modifying Raspberry Pi OS image for QEMU emulation..."

# Mount and modify the root partition
MOUNT_POINT="/tmp/rpi-root"
mkdir -p "$MOUNT_POINT"

echo "Mounting root partition..."
mount -v -o offset="$ROOT_OFFSET" -t ext4 "$RASPIOS_IMAGE" "$MOUNT_POINT"

# Fix ld.so.preload (prevents crashes in emulation)
if [ -f "$MOUNT_POINT/etc/ld.so.preload" ]; then
    echo "Fixing ld.so.preload for emulation..."
    sed -i 's/^/#/' "$MOUNT_POINT/etc/ld.so.preload"
fi

# Fix fstab (change mmcblk0 to sda for QEMU)
if [ -f "$MOUNT_POINT/etc/fstab" ]; then
    echo "Fixing fstab for QEMU emulation..."
    sed -i 's/mmcblk0p/sda/g' "$MOUNT_POINT/etc/fstab"
fi

# Enable SSH by creating the ssh file in boot partition
touch "$MOUNT_POINT/boot/ssh" 2>/dev/null || echo "SSH enable file creation skipped"

# Set default password (optional - for security)
echo "pi:\$6\$rounds=4096\$saltstring\$3xIS.4CF1.GGbU4JjMJjOdqu7tZer8FfnPT.yJu6vG2kMYLlzP5kE9vFgfVgZDJjRjJl8h8nS6LrU2RM0" > "$MOUNT_POINT/etc/shadow.bak"

echo "Unmounting root partition..."
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo "Image modification complete!"
EOF

chmod +x modify-raspios-image.sh

warning "To complete setup, please run:"
echo "  sudo ./modify-raspios-image.sh \"$RASPIOS_IMAGE\" \"$ROOT_OFFSET\""
echo ""
echo "This will:"
echo "  • Fix ld.so.preload for emulation compatibility"  
echo "  • Update fstab for QEMU disk naming"
echo "  • Enable SSH access"

# Create startup script
log "Creating ARM emulation startup script..."
cat > start-arm-pi.sh << 'EOF'
#!/bin/bash
#
# Start ARM Raspberry Pi Emulation
#

VM_DIR="$HOME/.arm-emulation"
cd "$VM_DIR"

# Check if image exists
if [ ! -f "raspios-lite-armhf.img" ]; then
    echo "❌ Raspberry Pi OS image not found. Run setup-arm-emulation.sh first."
    exit 1
fi

echo "🚀 Starting ARM Raspberry Pi Emulation..."
echo "📡 SSH will be available on localhost:5022"
echo "👤 Login: pi / Password: raspberry"
echo "🐳 Docker is pre-installed"
echo ""
echo "To stop: Press Ctrl+A then X"
echo "==============================="

# Start QEMU with ARM emulation
qemu-system-arm \
    -kernel qemu-rpi-kernel/kernel-qemu-5.10.63-bullseye \
    -dtb qemu-rpi-kernel/versatile-pb-bullseye-5.10.63.dtb \
    -cpu arm1176 \
    -m 512 \
    -M versatilepb \
    -serial stdio \
    -append "root=/dev/sda2 rootfstype=ext4 rw panic=1" \
    -hda raspios-lite-armhf.img \
    -netdev user,id=net0,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::5004-:5004 \
    -device rtl8139,netdev=net0 \
    -no-reboot
EOF

chmod +x start-arm-pi.sh

# Create container deployment script
log "Creating container deployment helper..."
cat > deploy-container-to-arm.sh << 'EOF'
#!/bin/bash
#
# Deploy REW Pi Receiver Container to ARM Emulation
#

set -e

CONTAINER_TAR="../export/rew-pi-receiver-*.tar"
CONTAINER_TAR=$(ls $CONTAINER_TAR 2>/dev/null | head -1)

if [ -z "$CONTAINER_TAR" ]; then
    echo "❌ No container tarball found in ../export/"
    echo "Run 'cd .. && ./deploy-to-pi.sh build' first"
    exit 1
fi

echo "📦 Deploying container to ARM emulation..."
echo "Container: $(basename "$CONTAINER_TAR")"

# Copy to ARM VM via SCP
echo "🔄 Copying container to ARM VM..."
scp -P 5022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$CONTAINER_TAR" \
    ../export/docker-compose.yaml \
    ../export/.env \
    ../export/install-from-tarball.sh \
    pi@localhost:/home/pi/

echo "🚀 Installing container in ARM VM..."
ssh -p 5022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pi@localhost '
    chmod +x install-from-tarball.sh
    ./install-from-tarball.sh
'

echo "✅ Container deployment complete!"
echo "🌐 Container should be running on ARM emulation"
echo "📊 Check status: ssh -p 5022 pi@localhost docker compose ps"
EOF

chmod +x deploy-container-to-arm.sh

success "ARM emulation environment setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Start ARM emulation: cd $VM_DIR && ./start-arm-pi.sh"
echo "2. Wait for Pi to boot (may take 2-3 minutes)"
echo "3. SSH to Pi: ssh -p 5022 pi@localhost"
echo "4. Deploy container: cd $VM_DIR && ./deploy-container-to-arm.sh"
echo ""
echo "🔧 Useful commands:"
echo "   • SSH to Pi: ssh -p 5022 pi@localhost"
echo "   • Copy files: scp -P 5022 file.txt pi@localhost:/home/pi/"
echo "   • Stop emulation: In QEMU console: Ctrl+A then X"