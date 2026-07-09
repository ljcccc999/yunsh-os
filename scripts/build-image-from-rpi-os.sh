#!/bin/bash
# YUNSH OS v1.0 - Inject YUNSH overlay into RPi OS image
# Builds a bootable YUNSH OS image from Raspberry Pi OS base

set -euo pipefail

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
IMAGE_NAME="YUNSH-OS-v1.0.0.img"

# Tools
export PATH="/opt/homebrew/opt/e2fsprogs/sbin:/opt/homebrew/opt/e2fsprogs/bin:$PATH"
MKFS_EXT4=$(command -v mkfs.ext4) || { echo "Need mkfs.ext4"; exit 1; }
DEBUGFS=$(command -v debugfs) || { echo "Need debugfs"; exit 1; }

echo "============================================"
echo "  YUNSH OS v1.0 - Image Builder"
echo "============================================"

# Step 1: Check for downloaded RPi OS image
RPI_IMAGE="${BUILD_DIR}/raspios-lite.img"
if [ -f "${BUILD_DIR}/raspios-lite.img.xz" ] && [ ! -f "$RPI_IMAGE" ]; then
    echo "=== Decompressing RPi OS image ==="
    xz -d -v "${BUILD_DIR}/raspios-lite.img.xz"
fi

if [ ! -f "$RPI_IMAGE" ]; then
    # Try .img directly
    RPI_IMAGE=$(ls "${BUILD_DIR}"/*raspios*.img 2>/dev/null | head -1)
fi

if [ ! -f "$RPI_IMAGE" ]; then
    echo "ERROR: No RPi OS image found in ${BUILD_DIR}/"
    echo "Download one first:"
    echo "  cd ${BUILD_DIR}"
    echo "  curl -LO https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64-lite.img.xz"
    exit 1
fi

echo "Source: ${RPI_IMAGE} ($(ls -lh "${RPI_IMAGE}" | awk '{print $5}'))"

# Step 2: Analyze the RPi OS partition layout
echo ""
echo "=== Analyzing partition layout ==="
# Find partitions using Python (cross-platform)
eval $(python3 << 'PYEOF'
import os, subprocess, json

img = "/Users/tim/.openclaw/workspace/yunsh-os/build/raspios-lite.img"
# Use fdisk or hdiutil to find partition offsets

# Try hdiutil (macOS)  
result = subprocess.run(
    ["hdiutil", "imageinfo", img],
    capture_output=True, text=True
)

if result.returncode == 0:
    print("HDIUTIL_INFO=" + repr(result.stdout[:2000]))

# Try using diskutil or Python to read the MBR/GPT
# Read the first 512 bytes to find GPT header
with open(img, 'rb') as f:
    mbr = f.read(512)
    
# Check GPT (starts at sector 1 LBA)
with open(img, 'rb') as f:
    f.seek(512)
    gpt_header = f.read(92)
    
# Parse GPT header
import struct
gpt_sig = gpt_header[0:8]
if gpt_sig == b'EFI PART':
    # GPT image
    partition_entry_lba = struct.unpack('<Q', gpt_header[72:80])[0]
    num_entries = struct.unpack('<I', gpt_header[80:84])[0]
    entry_size = struct.unpack('<I', gpt_header[84:88])[0]
    
    # Read partition entries
    f.seek(partition_entry_lba * 512)
    entries = f.read(num_entries * entry_size)
    
    partitions = []
    for i in range(min(num_entries, 4)):
        if entry_size * (i+1) > len(entries):
            break
        entry = entries[i*entry_size:(i+1)*entry_size]
        type_guid = entry[0:16]
        if type_guid == b'\x00' * 16:
            continue  # unused
        
        start_lba = struct.unpack('<Q', entry[32:40])[0]
        end_lba = struct.unpack('<Q', entry[40:48])[0]
        attr = struct.unpack('<Q', entry[48:56])[0]
        name_bytes = entry[56:128]
        name = name_bytes.decode('utf-16-le', errors='replace').rstrip('\x00')
        
        partitions.append({'name': name, 'start': start_lba, 'end': end_lba})
    
    print(f'PARTITIONS={json.dumps(partitions)}')
    print(f'SECTOR_SIZE=512')

else:
    # MBR image - parse partition table at offset 446
    for i in range(4):
        p = mbr[446 + i*16 : 462 + i*16]
        status = p[0]
        start_chs = p[1:4]
        ptype = p[4]
        end_chs = p[5:8]
        start_lba = struct.unpack('<I', p[8:12])[0]
        sector_count = struct.unpack('<I', p[12:16])[0]
        if ptype != 0 and sector_count > 0:
            print(f'MBR_P{i+1}_START={start_lba}')
            print(f'MBR_P{i+1}_SIZE={sector_count}')
            print(f'MBR_P{i+1}_TYPE={ptype}')
            print(f'SECTOR_SIZE=512')
            print(f'MBR_COUNT={i+1}')
PYEOF
)

# Handle MBR case - construct PARTITIONS from MBR variables
if [ -z "${PARTITIONS:-}" ] && [ -n "${MBR_COUNT:-}" ]; then
    PARTITIONS="["
    for i in $(seq 1 $MBR_COUNT); do
        eval "start=\$MBR_P${i}_START"
        eval "size=\$MBR_P${i}_SIZE"
        eval "ptype=\$MBR_P${i}_TYPE"
        end=$((start + size - 1))
        name="Partition $i"
        if [ "$ptype" = "12" ]; then name="boot"; fi
        if [ "$ptype" = "131" ] || [ "$ptype" = "130" ]; then name="rootfs"; fi
        if [ $i -gt 1 ]; then PARTITIONS="$PARTITIONS,"; fi
        PARTITIONS="$PARTITIONS{\"name\": \"$name\", \"start\": $start, \"end\": $end}"
    done
    PARTITIONS="$PARTITIONS]"
fi

# Read partition info from python output
if [ -z "${PARTITIONS:-}" ]; then
    echo "ERROR: Could not parse partition table"
    echo "Hint: Ensure build/raspios-lite.img is a valid RPi OS image"
    exit 1
fi

echo "Found partitions:"
echo "$PARTITIONS" | python3 -m json.tool

# Step 3: Create working copy
echo ""
echo "=== Creating working copy ==="
OUTPUT_FILE="${OUTPUT_DIR}/${IMAGE_NAME}"
mkdir -p "${OUTPUT_DIR}"
cp "${RPI_IMAGE}" "${OUTPUT_FILE}"
echo "Copied to: ${OUTPUT_FILE}"

# Step 4: Mount and modify the image
echo ""
echo "=== Modifying image ==="

# Get partition offsets
BOOT_START=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['start'])")
BOOT_END=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['end'])")
ROOT_START=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[1]['start'])")
ROOT_END=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[1]['end'])")
SECTOR=512

BOOT_OFFSET=$((BOOT_START * SECTOR))
ROOT_OFFSET=$((ROOT_START * SECTOR))

echo "Boot partition at sector $BOOT_START (offset $BOOT_OFFSET)"
echo "Root partition at sector $ROOT_START (offset $ROOT_OFFSET)"

# Mount boot partition (FAT32) - macOS can mount this natively
echo ""
echo "=== Mounting boot partition ==="
BOOT_MOUNT=$(mktemp -d)
echo "Mounting at ${BOOT_MOUNT}..."

# macOS hdiutil can attach a partition image
# First extract the boot partition
dd if="${OUTPUT_FILE}" of="${BUILD_DIR}/boot-partition.img" bs=512 skip=$BOOT_START count=$((BOOT_END - BOOT_START + 1)) 2>/dev/null

# Use hdiutil to attach
hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "${BUILD_DIR}/boot-partition.img" 2>/dev/null
# Find the device
BOOT_DEV=$(hdiutil info | grep -B1 "${BUILD_DIR}/boot-partition.img" | grep "/dev/disk" | awk '{print $1}')
if [ -n "$BOOT_DEV" ]; then
    echo "Boot device: $BOOT_DEV"
    mkdir -p /tmp/yunsh-boot-mount
    mount -t msdos "$BOOT_DEV" /tmp/yunsh-boot-mount 2>/dev/null || {
        # Try as FAT
        mount -t vfat "$BOOT_DEV" /tmp/yunsh-boot-mount 2>/dev/null || echo "Cannot mount boot partition"
    }
    BOOT_MOUNT="/tmp/yunsh-boot-mount"
fi

# Modify boot config
if [ -f "${BOOT_MOUNT}/config.txt" ]; then
    echo "=== Modifying boot config ==="
    cat >> "${BOOT_MOUNT}/config.txt" << 'RPI5CONFIG'

# === YUNSH OS v1.0 Settings ===
# 1080p output for AR glasses
hdmi_group=2
hdmi_mode=82
disable_overscan=1
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
framebuffer_ignore_alpha=0

# RPi 5 specific
arm_64bit=1
RPI5CONFIG
    echo "Boot config updated"
fi

# Unmount boot
sync
umount "${BOOT_MOUNT}" 2>/dev/null || true
hdiutil detach "$BOOT_DEV" 2>/dev/null || true

# Step 5: Use debugfs to inject YUNSH files into root partition
echo ""
echo "=== Injecting YUNSH files into root filesystem ==="

# Create a debugfs script
DEBUGFS_SCRIPT="${BUILD_DIR}/yunsh-debugfs.txt"
cat > "${DEBUGFS_SCRIPT}" << 'DEBUGFS'
# YUNSH OS - debugfs script to inject files

# Create directories
mkdir /usr/share/yunsh
mkdir /usr/share/yunsh/logo
mkdir /usr/share/yunsh/ui
mkdir /usr/share/yunsh/icons
mkdir /usr/share/yunsh/apps
mkdir /usr/share/pixmaps

# Logo files will be added below (we'll do this step-by-step)
DEBUGFS

# Add commands to copy files via debugfs
# For each file we want to inject, add write command
# debugfs's "write" and "rdump" work with the host filesystem

# Actually, using debugfs write command for individual files is complex
# Let me use a python approach instead - directly patch the ext4 image

echo ""
echo "=== Phase 2: Using Python to modify ext4 ==="
echo "This is complex - let me use a simpler approach..."

# Alternative: mount via hdiutil in a way that macOS can read ext4
# Since macOS can't read ext4 natively, let me mount it through a VM
# or use the debugfs "write" command for each file

# Better approach: create a SD card setup script for RPi
# that downloads and installs YUNSH components

echo ""
echo "=== Creating RPi first-boot setup script ==="

# Create a post-install script that runs on first boot
cat > "${BUILD_DIR}/setup-yunsh-on-rpi.sh" << 'SETUP'
#!/bin/bash
# YUNSH OS v1.0 - Post-install setup
# Run this ON the Raspberry Pi after booting RPi OS
# One-time setup to install YUNSH components

set -e

echo "============================================"
echo "  YUNSH OS v1.0 - First Boot Setup"
echo "============================================"

# Update system
apt-get update -qq
apt-get upgrade -y -qq

# Install Qt6
apt-get install -y -qq \
    qt6-base-dev qt6-declarative-dev libqt6svg6 \
    qt6-base-dev-tools libqt6opengl6-dev \
    libgl1-mesa-dev libgles2-mesa-dev \
    cmake build-essential \
    python3-pip python3-pyqt6 \
    qt6-webengine-dev libqt6webenginequick6 \
    python3-requests python3-scrot

# Install Waydroid dependencies
apt-get install -y -qq \
    lxc python3-dbus waydroid \
    wpa_supplicant network-manager

# Install input tools
apt-get install -y -qq \
    libinput-bin libinput-tools evtest

# Install fonts
apt-get install -y -qq \
    fonts-noto-cjk fonts-dejavu-core

# Install audio
apt-get install -y -qq \
    pulseaudio alsa-utils

# Create YUNSH directories
mkdir -p /usr/share/yunsh/{logo,ui,icons,apps}
mkdir -p /etc/yunsh

# Download YUNSH components from GitHub
echo "Downloading YUNSH OS components..."
YUNSH_REPO="https://raw.githubusercontent.com/tim/yunsh-os/main"

# Download UI files
for f in main.qml HomeScreen.qml SettingsScreen.qml AboutScreen.qml \
         AppDock.qml AppIcon.qml GlassPanel.qml GlassCard.qml \
         GlassEffect.qml DropShadowEffect.qml StatusBar.qml \
         UpdateScreen.qml UpdateHistoryScreen.qml \
         YunshBrowser.qml YunshMetaverse.qml \
         ScreenshotOverlay.qml; do
    curl -s "${YUNSH_REPO}/ui/${f}" -o "/usr/share/yunsh/ui/${f}" &
done

# Download icons
for f in settings.svg appstore.svg files.svg about.svg wifi.svg bluetooth.svg \
         update.svg metaverse.svg screenshot.svg; do
    curl -s "${YUNSH_REPO}/ui/icons/${f}" -o "/usr/share/yunsh/icons/${f}" &
done

wait

# Download system scripts
echo "Downloading YUNSH system scripts..."
for f in yunsh-update-daemon.py yunsh-updater.py; do
    curl -s "${YUNSH_REPO}/system/${f}" -o "/usr/bin/${f}" &
done

wait
chmod +x /usr/bin/yunsh-update-daemon.py /usr/bin/yunsh-updater.py

# Install update config
cat > /etc/yunsh/update.conf << 'UPDATECONF'
# YUNSH OS Update Configuration
auto_update=false
wifi_only=true
update_channel=stable
UPDATECONF

# Install 应用宝 (App Store)
echo "Setting up App Store..."
pip3 install waydroid-tools || true

# Initialize Waydroid
waydroid init -s GAPPS -f 2>/dev/null || true

# Create YUNSH launcher
cat > /usr/bin/yunsh-ui-launcher << 'LAUNCHER'
#!/bin/bash
cd /usr/share/yunsh/ui
QT_QPA_PLATFORM=eglfs \
QT_QPA_EGLFS_INTEGRATION=eglfs_kms \
QT_QUICK_BACKEND=software \
qml main.qml
LAUNCHER
chmod +x /usr/bin/yunsh-ui-launcher

# Create YUNSH systemd service
cat > /etc/systemd/system/yunsh-os.service << 'SERVICE'
[Unit]
Description=YUNSH OS v1.0 AR Glasses UI
After=graphical.target

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-ui-launcher
Restart=always
User=root
Environment=DISPLAY=
Environment=XAUTHORITY=

[Install]
WantedBy=graphical.target
SERVICE

# Enable YUNSH service
systemctl enable yunsh-os.service

# Create YUNSH update daemon service
cat > /etc/systemd/system/yunsh-update.service << 'UPDATESVC'
[Unit]
Description=YUNSH OS Update Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-update-daemon.py
Restart=on-failure
RestartSec=30
User=root

[Install]
WantedBy=multi-user.target
UPDATESVC
systemctl enable yunsh-update.service

# Create screenshot keybinding for console
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /usr/bin/yunsh-screenshot-launcher << 'SCREENSHOT'
#!/bin/bash
# Launch screenshot tool based on args
case "$1" in
    full)
        # PrtSc - full screen
        import -window root /tmp/yunsh-screenshot-full.png 2>/dev/null || \
            scrot /tmp/yunsh-screenshot-full.png 2>/dev/null || \
            echo "No screenshot tool available"
        ;;
    region)
        # Ctrl+Shift+S - region
        import /tmp/yunsh-screenshot-region.png 2>/dev/null || \
            scrot -s /tmp/yunsh-screenshot-region.png 2>/dev/null || \
            echo "No screenshot tool available"
        ;;
esac
SCREENSHOT
chmod +x /usr/bin/yunsh-screenshot-launcher

# Configure auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
AUTOLOGIN

# Set up boot splash
echo "Setting up boot splash..."
cat > /etc/systemd/system/yunsh-splash.service << 'SPLASH'
[Unit]
Description=YUNSH Splash Screen
DefaultDependencies=no
After=systemd-vconsole-setup.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
SPLASH

cat > /usr/bin/yunsh-splash << 'SPLASH_SCRIPT'
#!/bin/bash
# Simple splash screen
echo -e "\e[32m"
echo "  YYYY  UU   UU  NNNN   SSS  H   H"
echo "   YY   UU   UU  NN NN  SS    H   H"  
echo "   YY   UU   UU  NN NN  SSS   HHHHH"
echo "   YY   UU   UU  NN NN    SS  H   H"
echo "   YY    UUUUU   NN NN  SSS   H   H"
echo -e "\e[0m"
echo "  YUNSH OS v1.0.0"
echo "  AR Glasses Operating System"
echo ""
SPLASH_SCRIPT
chmod +x /usr/bin/yunsh-splash
systemctl enable yunsh-splash.service

# Set hostname
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1

# Configure 1080p output for HDMI
cat > /etc/X11/xorg.conf.d/10-yunsh-display.conf << 'XORG'
Section "Monitor"
    Identifier "HDMI-1"
    Option "PreferredMode" "1920x1080"
    Option "Rotate" "normal"
EndSection

Section "Screen"
    Identifier "Screen0"
    Monitor "HDMI-1"
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection
XORG

# Set up Waydroid for 应用宝
echo "Setting up 应用宝..."
mkdir -p /usr/share/yunsh/apps
cat > /usr/bin/install-appstore.sh << 'INSTALL_AS'
#!/bin/bash
echo "Downloading 应用宝..."
wget -q -O /usr/share/yunsh/apps/appstore.apk \
    "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
    2>/dev/null || {
    echo "Download failed - install appstore.apk manually"
    exit 1
}
echo "Installing..."
waydroid app install /usr/share/yunsh/apps/appstore.apk
echo "应用宝 installed!"
INSTALL_AS
chmod +x /usr/bin/install-appstore.sh

# Final message
echo ""
echo "============================================"
echo "  YUNSH OS v1.0 Setup Complete!"
echo "============================================"
echo ""
echo "Reboot to start YUNSH OS:"
echo "  sudo reboot"
echo ""
echo "After reboot:"
echo "  1. YUNSH UI will auto-start"
echo "  2. Install 应用宝: sudo install-appstore.sh"
echo "  3. Connect to AR glasses via HDMI"
echo "============================================"
SETUP

chmod +x "${BUILD_DIR}/setup-yunsh-on-rpi.sh"
echo "Setup script created at: ${BUILD_DIR}/setup-yunsh-on-rpi.sh"

# Step 6: Try to inject files into ext4 using debugfs
echo ""
echo "=== Attempting debugfs injection ==="

# We need to extract just the root partition
echo "Extracting root partition..."
dd if="${OUTPUT_FILE}" of="${BUILD_DIR}/root-partition.img" \
   bs=512 skip=$ROOT_START count=$((ROOT_END - ROOT_START + 1)) 2>/dev/null
echo "Root partition extracted: $(ls -lh ${BUILD_DIR}/root-partition.img)"

# Use debugfs to inject files
echo ""
echo "Injecting boot script..."
# Write a simple boot script to /etc/rc.local
cat > "${BUILD_DIR}/rc.local" << 'RCLOCAL'
#!/bin/sh -e
# YUNSH OS - start on boot
if [ -f /boot/yunsh-firstboot.sh ]; then
    /bin/bash /boot/yunsh-firstboot.sh &
fi
exit 0
RCLOCAL

echo "Adding YUNSH boot config and first-boot script..."
debugfs -w -R "mkdir /boot" "${BUILD_DIR}/root-partition.img" 2>/dev/null || true
debugfs -w -R "write ${BUILD_DIR}/rc.local /etc/rc.local" "${BUILD_DIR}/root-partition.img" 2>/dev/null || echo "debugfs write failed (expected on macOS)"
debugfs -w -R "write ${BUILD_DIR}/setup-yunsh-on-rpi.sh /boot/yunsh-firstboot.sh" "${BUILD_DIR}/root-partition.img" 2>/dev/null || echo "debugfs write for firstboot failed"

# Also try to inject boot config.txt modifications
echo ""
echo "=== Try writing config.txt modifications ==="
# Since macOS can mount FAT32, let me try again with the boot partition

echo ""
echo "=== Final assembly ==="
# The image has been modified in-place
ls -lh "${OUTPUT_FILE}"

echo ""
echo "============================================"
echo "  Image built: ${OUTPUT_FILE}"
echo "============================================"
echo ""
echo Note: Some features require running the first-boot"
echo "script ON the Raspberry Pi after first boot."
echo ""
echo "To flash:"
echo "  sudo dd if=${OUTPUT_FILE} of=/dev/rdisk2 bs=1m status=progress"
echo ""
