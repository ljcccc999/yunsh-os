#!/bin/bash
# YUNSH OS v1.0 - Mac SD Card Flash Script
# Flashes YUNSH OS image to SD card from macOS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  YUNSH OS v1.0 - SD Card Flasher (macOS)"
echo "============================================"

# Find the image
if [ -f "${SCRIPT_DIR}/YUNSH-OS-v1.0.1.img" ]; then
    IMAGE_PATH="${SCRIPT_DIR}/YUNSH-OS-v1.0.1.img"
elif [ -f "${SCRIPT_DIR}/../output/YUNSH-OS-v1.0.1.img" ]; then
    IMAGE_PATH="${SCRIPT_DIR}/../output/YUNSH-OS-v1.0.1.img"
else
    echo -e "${RED}ERROR: YUNSH-OS-v1.0.1.img not found!${NC}"
    echo "Usage: $0 [path/to/image.img]"
    exit 1
fi

echo ""
echo "Image: ${IMAGE_PATH}"
echo "Size:  $(ls -lh "${IMAGE_PATH}" | awk '{print $5}')"
echo ""

# List available disks
echo -e "${YELLOW}Available disks:${NC}"
diskutil list internal external | grep -E "^/dev/disk[0-9]|^       [0-9]:"
echo ""

# Ask for disk
echo -e "${RED}⚠️  WARNING: This will ERASE the target disk!${NC}"
echo ""
diskutil list
echo ""
read -p "Enter disk to flash (e.g., disk2): " DISK_NAME

# Validate
if [ ! -e "/dev/${DISK_NAME}" ]; then
    echo -e "${RED}ERROR: /dev/${DISK_NAME} does not exist${NC}"
    exit 1
fi

# Confirm
echo ""
echo -e "${YELLOW}About to flash to /dev/${DISK_NAME}${NC}"
echo -e "${RED}ALL DATA ON /dev/${DISK_NAME} WILL BE DESTROYED!${NC}"
echo ""
read -p "Type YES to confirm: " CONFIRM
if [ "${CONFIRM}" != "YES" ]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "=== Step 1: Unmounting /dev/${DISK_NAME} ==="
diskutil unmountDisk "/dev/${DISK_NAME}" || true

echo ""
echo "=== Step 2: Flashing YUNSH OS to /dev/${DISK_NAME} ==="
echo "This may take a few minutes. Do not disconnect your SD card."
echo ""
sudo dd if="${IMAGE_PATH}" of="/dev/r${DISK_NAME}" bs=1m status=progress

echo ""
echo "=== Step 3: Syncing writes ==="
sync

echo ""
echo "=== Step 4: Ejecting SD card ==="
diskutil eject "/dev/${DISK_NAME}"

echo ""
echo -e "${GREEN}✅ YUNSH OS flashed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Insert SD card into Raspberry Pi 4B/5"
echo "  2. Connect YUNSH AR glasses to HDMI port"
echo "  3. Connect USB mouse and keyboard"
echo "  4. Power on the Raspberry Pi"
echo "  5. YUNSH OS will boot automatically!"
echo ""

# Open the RPi image folder
open "${SCRIPT_DIR}" 2>/dev/null || true
