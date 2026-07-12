#!/bin/bash
# YUNSH OS — Boot partition injection using mtools
# This properly handles FAT32 directory entries

set -e
YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_IMG="${YUNSH_DIR}/output/YUNSH-OS-v1.0.1.img"
BASE_IMG="${BUILD_DIR}/raspios-lite.img"

echo "=============================================="
echo "  Boot Partition Injection (mtools)"
echo "=============================================="

# Step 1: Extract boot partition from BASE image
echo ""
echo "=== Parsing MBR ==="
eval $(python3 << 'PYEOF'
import struct
with open("'"${BASE_IMG}"'", "rb") as f:
    mbr = f.read(512)
boot_lba = struct.unpack_from("<I", mbr, 454)[0]
boot_sectors = struct.unpack_from("<I", mbr, 458)[0]
print(f"BOOT_LBA={boot_lba} BOOT_SECTORS={boot_sectors}")
PYEOF
)
echo "Boot: LBA=$BOOT_LBA sectors=$BOOT_SECTORS"

# Step 2: Extract boot from base
echo ""
echo "=== Extracting boot from base image ==="
BOOT_IMG="${BUILD_DIR}/boot-partition-mtools.img"
dd if="${BASE_IMG}" of="${BOOT_IMG}" bs=512 skip=$BOOT_LBA count=$BOOT_SECTORS 2>/dev/null
echo "  ✓ Extracted (512 MB)"

# Step 3: Copy our config.txt and cmdline.txt using mtools
echo ""
echo "=== Writing YUNSH config.txt ==="
cat > "${BUILD_DIR}/yunsh-config.txt" << 'CONFIGEOF'
# YUNSH OS - v1.0.1
# Raspberry Pi 5 config
arm_64bit=1
dtoverlay=vc4-kms-v3d
gpu_mem=256
gpu_mem_256=128
disable_splash=1
dtparam=i2c_arm=on
dtparam=i2c_vc=on
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=82
display_auto_detect=1
dtparam=audio=on
boot_order=0xf41
dtoverlay=disable-bt
CONFIGEOF

# Use mtools drive image
export MTOOLS_SKIP_CHECK=1
MTOOLS_DRIVE="image:${BOOT_IMG}"

# Delete config.txt and write new one
mdel -i "${BOOT_IMG}" ::CONFIG.TXT 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/yunsh-config.txt" ::CONFIG.TXT
echo "  ✓ CONFIG.TXT written"

echo ""
echo "=== Writing YUNSH cmdline.txt ==="
# Read current cmdline and modify
mtype -i "${BOOT_IMG}" ::CMDLINE.TXT 2>/dev/null > "${BUILD_DIR}/yunsh-cmdline-orig.txt" || true
ORIG=$(cat "${BUILD_DIR}/yunsh-cmdline-orig.txt" 2>/dev/null || echo "")
echo "  Original: $ORIG"

MODIFIED="${ORIG/console=serial0,115200/console=tty1}"
if [[ "$MODIFIED" != *"consoleblank"* ]]; then
    MODIFIED="$MODIFIED consoleblank=0 logo.nologo vt.global_cursor_default=0 quiet"
fi
echo "  Modified: $MODIFIED"
echo "$MODIFIED" > "${BUILD_DIR}/yunsh-cmdline.txt"

mdel -i "${BOOT_IMG}" ::CMDLINE.TXT 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/yunsh-cmdline.txt" ::CMDLINE.TXT
echo "  ✓ CMDLINE.TXT written"

echo ""
echo "=== Copying YUNSH boot files ==="
# firstboot script
mcopy -i "${BOOT_IMG}" "${YUNSH_DIR}/boot/yunsh-firstboot.sh" ::YUNSH-FI.SH
echo "  ✓ yunsh-firstboot.sh"

# iptables script
mcopy -i "${BOOT_IMG}" "${YUNSH_DIR}/boot/yunsh-iptables.sh" ::YUNSH-IP.SH
echo "  ✓ yunsh-iptables.sh"

# splash BMP (720p version fits)
if [ -f "${BUILD_DIR}/splash/yunsh-splash-full-720p.bmp" ]; then
    mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/splash/yunsh-splash-full-720p.bmp" ::YUNSH-SP.BMP
    echo "  ✓ yunsh-splash-full-720p.bmp"
else
    echo "  ⚠ splash BMP not found"
fi

echo ""
echo "=== Verifying boot partition ==="
mdir -i "${BOOT_IMG}" ::
echo ""

# Step 4: Write boot back to output image
echo "=== Writing boot back to output image ==="
# Need to calculate the offset: BOOT_LBA * 512
BOOT_OFFSET=$((BOOT_LBA * 512))
dd if="${BOOT_IMG}" of="${OUTPUT_IMG}" bs=512 seek=$BOOT_LBA count=$BOOT_SECTORS conv=notrunc 2>/dev/null
sync
echo "  ✓ Boot partition written back"

# Step 5: Verify config.txt
echo ""
echo "=== Config.txt content ==="
python3 -c "
import struct
with open('${OUTPUT_IMG}', 'rb') as f:
    f.seek($BOOT_OFFSET)
    boot = f.read(1024*1024)
    # Search for our config
    idx = boot.find(b'YUNSH OS')
    if idx >= 0:
        end = boot.find(b'dtoverlay=disable-bt', idx)
        if end >= 0:
            end = boot.find(b'\n', end) + 1
        print(boot[idx-3:end+5].decode('ascii', errors='replace'))
    else:
        print('YUNSH OS marker not found!')
        # Show what's at start of data area
        bytes_per_sec = struct.unpack_from('<H', boot, 11)[0]
        reserved_sec = struct.unpack_from('<H', boot, 14)[0]
        num_fats = boot[16]
        sec_per_fat = struct.unpack_from('<I', boot, 36)[0]
        data_start = (reserved_sec + num_fats * sec_per_fat) * bytes_per_sec
        f.seek($BOOT_OFFSET + data_start)
        print('First 200 bytes of root dir:')
        print(f.read(200).decode('ascii', errors='replace')[:200])
"

# Cleanup
rm -f "${BUILD_DIR}/yunsh-config.txt" "${BUILD_DIR}/yunsh-cmdline.txt" "${BUILD_DIR}/yunsh-cmdline-orig.txt"
echo ""
echo "✅ Boot partition injected successfully!"
