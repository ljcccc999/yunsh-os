#!/bin/bash
# YUNSH OS v1.0 - Image Builder (macOS)
# Injects YUNSH overlay into RPi OS image using debugfs for ext4
#
# Usage:  ./build-image-from-rpi-os.sh
# Prereq: e2fsprogs via Homebrew (brew install e2fsprogs)
# Input:  build/raspios-lite.img (download from Raspberry Pi)
# Output: output/YUNSH-OS-v1.0.1.img

set -euo pipefail

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
IMAGE_NAME="YUNSH-OS-v1.0.1.img"

# macOS Homebrew e2fsprogs (keg-only, link to Cellar directly)
E2FSPROGS="/opt/homebrew/Cellar/e2fsprogs/1.47.4"
DEBUGFS="${E2FSPROGS}/sbin/debugfs"
MKE2FS="${E2FSPROGS}/sbin/mke2fs"

echo "============================================"
echo "  YUNSH OS v1.0 - Image Builder"
echo "============================================"

# ─── Step 1: Find RPi OS image ──────────────────────
RPI_IMAGE="${BUILD_DIR}/raspios-lite.img"
if [ -f "${BUILD_DIR}/raspios-lite.img.xz" ] && [ ! -f "$RPI_IMAGE" ]; then
    echo "=== Decompressing RPi OS image ==="
    xz -d -v "${BUILD_DIR}/raspios-lite.img.xz"
fi

if [ ! -f "$RPI_IMAGE" ]; then
    RPI_IMAGE=$(ls "${BUILD_DIR}"/*raspios*.img 2>/dev/null | head -1 || true)
fi

if [ ! -f "$RPI_IMAGE" ]; then
    echo "ERROR: No RPi OS image found in ${BUILD_DIR}/"
    echo "Download one:"
    echo "  cd ${BUILD_DIR}"
    echo "  curl -LO https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64-lite.img.xz"
    exit 1
fi

echo "Source: ${RPI_IMAGE} ($(ls -lh "${RPI_IMAGE}" | awk '{print $5}'))"

# ─── Step 2: Parse partition table ──────────────────
echo ""
echo "=== Analyzing partition layout ==="
eval $(python3 << 'PYEOF'
import os, struct, json

img = "/Users/tim/.openclaw/workspace/yunsh-os/build/raspios-lite.img"

with open(img, 'rb') as f:
    mbr = f.read(512)
    f.seek(512)
    gpt_header = f.read(92)

gpt_sig = gpt_header[0:8]
if gpt_sig == b'EFI PART':
    partition_entry_lba = struct.unpack('<Q', gpt_header[72:80])[0]
    num_entries = struct.unpack('<I', gpt_header[80:84])[0]
    entry_size = struct.unpack('<I', gpt_header[84:88])[0]
    f.seek(partition_entry_lba * 512)
    entries = f.read(num_entries * entry_size)
    partitions = []
    for i in range(min(num_entries, 8)):
        entry = entries[i*entry_size:(i+1)*entry_size]
        type_guid = entry[0:16]
        if type_guid == b'\x00' * 16:
            continue
        start_lba = struct.unpack('<Q', entry[32:40])[0]
        end_lba = struct.unpack('<Q', entry[40:48])[0]
        name_bytes = entry[56:128]
        name = name_bytes.decode('utf-16-le', errors='replace').rstrip('\x00')
        partitions.append({'name': name if name else 'unknown', 'start': start_lba, 'end': end_lba})
    print(f'PARTITIONS={json.dumps(partitions)}')
    print(f'SECTOR_SIZE=512')
else:
    for i in range(4):
        p = mbr[446 + i*16 : 462 + i*16]
        ptype = p[4]
        start_lba = struct.unpack('<I', p[8:12])[0]
        sector_count = struct.unpack('<I', p[12:16])[0]
        if ptype != 0 and sector_count > 0:
            print(f'MBR_P{i+1}_START={start_lba}')
            print(f'MBR_P{i+1}_SIZE={sector_count}')
            print(f'MBR_P{i+1}_TYPE={ptype}')
            print(f'MBR_COUNT={i+1}')
            print(f'SECTOR_SIZE=512')
PYEOF
)

# If MBR, build PARTITIONS
if [ -z "${PARTITIONS:-}" ] && [ -n "${MBR_COUNT:-}" ]; then
    PARTITIONS="["
    for i in $(seq 1 $MBR_COUNT); do
        eval "start=\$MBR_P${i}_START"
        eval "size=\$MBR_P${i}_SIZE"
        eval "ptype=\$MBR_P${i}_TYPE"
        end=$((start + size - 1))
        name="Partition $i"
        [ "$ptype" = "12" ] && name="boot"
        [ "$ptype" = "131" ] || [ "$ptype" = "130" ] && name="rootfs"
        [ $i -gt 1 ] && PARTITIONS="$PARTITIONS,"
        PARTITIONS="$PARTITIONS{\"name\": \"$name\", \"start\": $start, \"end\": $end}"
    done
    PARTITIONS="$PARTITIONS]"
fi

if [ -z "${PARTITIONS:-}" ]; then
    echo "ERROR: Could not parse partition table"
    exit 1
fi

echo "Partitions:"
echo "$PARTITIONS" | python3 -m json.tool

# ─── Step 3: Create working copy ────────────────────
echo ""
echo "=== Creating working copy ==="
OUTPUT_FILE="${OUTPUT_DIR}/${IMAGE_NAME}"
mkdir -p "${OUTPUT_DIR}"
cp "${RPI_IMAGE}" "${OUTPUT_FILE}"
echo "Copied to: ${OUTPUT_FILE}"

# ─── Step 4: Get partition offsets ──────────────────
SECTOR=512
BOOT_START=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['start'])")
BOOT_END=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['end'])")
ROOT_START=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[1]['start'])")
ROOT_END=$(echo "$PARTITIONS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[1]['end'])")
BOOT_OFFSET=$((BOOT_START * SECTOR))
ROOT_OFFSET=$((ROOT_START * SECTOR))

echo "Boot partition: sector $BOOT_START-$BOOT_END (offset ${BOOT_OFFSET})"
echo "Root partition: sector $ROOT_START-$ROOT_END (offset ${ROOT_OFFSET})"

# ════════════════════════════════════════════════════════
# STEP 4b: Generate boot splash screen
# ════════════════════════════════════════════════════════
echo "=== Generating boot splash screen ==="
mkdir -p "${YUNSH_DIR}/build/splash"
# Generate splash using Python + PIL
python3 << 'SPLASHGEN' 2>&1
import os
from PIL import Image, ImageDraw, ImageFont

logo = Image.open("logo/logo-512.png").convert("RGBA")
W, H = 1920, 1080
lw, lh = 220, 220  # logo size
bg = Image.new("RGB", (W, H), (0, 0, 0))

logo_small = logo.resize((lw, lh), Image.LANCZOS)
lx, ly = (W-lw)//2, (H-lh)//2 - 40

if logo_small.mode == "RGBA":
    r, g, b, a = logo_small.split()
    bg.paste(logo_small, (lx, ly), mask=a)
else:
    bg.paste(logo_small, (lx, ly))

draw = ImageDraw.Draw(bg)
try:
    font_lg = ImageFont.truetype("/System/Library/Fonts/SFNSDisplay.ttf", 44)
except:
    font_lg = ImageFont.load_default()

text = "YUNSH OS"
bbox = draw.textbbox((0, 0), text, font=font_lg)
draw.text(((W - (bbox[2]-bbox[0]))//2, ly+lh+50), text, fill=(0, 212, 255), font=font_lg)

os.makedirs("build/splash", exist_ok=True)

# Generate raw fb dumps
for name, has_text in [("yunsh-splash-logo", False), ("yunsh-splash-full", True)]:
    img = Image.new("RGB", (W, H), (0, 0, 0))
    if logo_small.mode == "RGBA":
        r, g, b, a = logo_small.split()
        img.paste(logo_small, (lx, ly), mask=a)
    else:
        img.paste(logo_small, (lx, ly))
    if has_text:
        d = ImageDraw.Draw(img)
        try:
            ft = ImageFont.truetype("/System/Library/Fonts/SFNSDisplay.ttf", 44)
        except:
            ft = ImageFont.load_default()
        bb = d.textbbox((0, 0), text, font=ft)
        d.text(((W - (bb[2]-bb[0]))//2, ly+lh+50), text, fill=(0, 212, 255), font=ft)
    # Raw BGRA — use Image.tobytes() for 100x speedup over pixel loop
    fb_data = img.tobytes()  # RGB, 3 bytes per pixel
    pixel_count = W * H
    # PIL 'RGB' → BGRA: swap R/B, add alpha channel
    # fb[0::4] = every 4th byte starting at 0 (B channel)
    # fb_data[2::3] = every 3rd byte starting at 2 (B in RGB)
    fb = bytearray(pixel_count * 4)
    b_vals = fb_data[2::3]  # Extract B across all pixels
    g_vals = fb_data[1::3]  # Extract G
    r_vals = fb_data[0::3]  # Extract R
    fb[0::4] = b_vals  # BGRA byte 0 = B
    fb[1::4] = g_vals  # BGRA byte 1 = G
    fb[2::4] = r_vals  # BGRA byte 2 = R
    # byte 3 = A = 0 (already 0 from bytearray init)
    with open(f"build/splash/{name}.raw", "wb") as f:
        f.write(fb)
    # Also save BMP for fallback
    img.save(f"build/splash/{name}.bmp", "BMP")
    print(f"  {name}.raw + .bmp generated")

# 720p version (full only)
img_720 = bg.resize((1280, 720), Image.LANCZOS)
img_720.save("build/splash/yunsh-splash-full-720p.bmp", "BMP")
print("Splash generated ✓")
SPLASHGEN
echo "   splash: logo → YUNSH OS ✓"

# ════════════════════════════════════════════════════════
# STEP 4c: Download 应用宝 APK (pre-package in image)
# ════════════════════════════════════════════════════════
echo "=== Downloading 应用宝 APK ==="
APPS_DIR="${YUNSH_DIR}/build/apps"
mkdir -p "${APPS_DIR}"
APK_FILE="${APPS_DIR}/appstore.apk"

# Try multiple download URLs
APK_DOWNLOADED=false
for url in \
    "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
    "https://appdownload.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader.apk" \
    "https://sj.qq.com/" ; do
    echo "  Trying: $url"
    if curl -sSL --connect-timeout 15 --max-time 120 -o "${APK_FILE}" "$url" 2>/dev/null; then
        file_size=$(stat -f%z "${APK_FILE}" 2>/dev/null || stat -c%s "${APK_FILE}" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 1000000 ]; then
            echo "  ✅ 下载成功: $(ls -lh ${APK_FILE} | awk '{print $5}')"
            APK_DOWNLOADED=true
            break
        fi
    fi
done

if [ "$APK_DOWNLOADED" = false ]; then
    echo "  ⚠ 下载失败，将使用运行时下载方式"
    # Create placeholder - firstboot will download it
    echo "placeholder" > "${APK_FILE}"
fi

# ════════════════════════════════════════════════════════
# STEP 5: Modify BOOT partition (FAT32 — macOS native)
# ════════════════════════════════════════════════════════
echo ""
echo "=== Step 5: Modifying boot partition ==="

# Extract boot partition
BOOT_PARTITION_IMG="${BUILD_DIR}/boot-partition.img"
dd if="${OUTPUT_FILE}" of="${BOOT_PARTITION_IMG}" bs=512 \
   skip=$BOOT_START count=$((BOOT_END - BOOT_START + 1)) 2>/dev/null

# Attach boot partition image
BOOT_DEV=""
for try in 1 2 3; do
    BOOT_DEV=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "${BOOT_PARTITION_IMG}" 2>/dev/null | grep "/dev/disk" | head -1 | awk '{print $1}')
    [ -n "$BOOT_DEV" ] && break
    for wait_i in 1 2 3 4 5; do sleep 1; done
done

if [ -z "$BOOT_DEV" ]; then
    echo "WARNING: Could not attach boot partition after 3 tries"
    echo "Falling back to mtools for boot partition injection..."
    USE_MTOOLS=1
fi

BOOT_MOUNT="/tmp/yunsh-boot-mount"
mkdir -p "${BOOT_MOUNT}"
mount -t msdos "$BOOT_DEV" "${BOOT_MOUNT}" 2>&1 || \
mount -t vfat "$BOOT_DEV" "${BOOT_MOUNT}" 2>&1 || {
    echo "ERROR: Cannot mount boot partition"
    hdiutil detach "$BOOT_DEV" 2>/dev/null || true
    exit 1
}
echo "Boot partition mounted at ${BOOT_MOUNT}"

# 5a. Modify config.txt
CONFIG_FILE="${BOOT_MOUNT}/config.txt"
if [ -f "$CONFIG_FILE" ]; then
    echo "→ Updating config.txt with YUNSH display settings"
    # Remove existing YUNSH section if present
    sed -i '' '/^# === YUNSH OS/,/^hdmi_force_hotplug=1$/d' "$CONFIG_FILE" 2>/dev/null || true
    # Remove Pi 4 specific settings that conflict with Pi 5
    sed -i '' '/^arm_freq=1500/d; /^gpu_freq=600/d; /^kernel_address/d; /^dtoverlay=vc4-fkms-v3d/d; /^force_turbo/d' "$CONFIG_FILE" 2>/dev/null || true
    # Remove duplicate dtparam=audio (we have [pi5] section below)
    sed -i '' '/^dtparam=audio/d' "$CONFIG_FILE" 2>/dev/null || true
    
    cat >> "$CONFIG_FILE" << 'RPI5CONFIG'

# === YUNSH OS v1.0 Settings ===
arm_64bit=1

[pi5]
# Pi 5 specific: KMS display, no legacy hdmi hacks
dtoverlay=vc4-kms-v3d
disable_splash=1
dtparam=audio=off
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
framebuffer_ignore_alpha=0
disable_overscan=1

[all]
# I2C for IMU
dtparam=i2c_arm=on
RPI5CONFIG
    echo "   config.txt updated"
fi

# 5a2. Modify cmdline.txt - remove boot logo, quiet kernel messages
CMDLINE_FILE="${BOOT_MOUNT}/cmdline.txt"
if [ -f "${CMDLINE_FILE}" ]; then
    echo "→ Updating cmdline.txt"
    # Read current cmdline, remove any existing quiet/logo.nologo, add ours
    CURRENT=$(cat "${CMDLINE_FILE}")
    # Remove old splash-related args if present
    CLEANED=$(echo "$CURRENT" | sed 's/ quiet//g; s/ logo.nologo//g; s/ splash//g; s/ consoleblank=[0-9]*//g' 2>/dev/null || echo "$CURRENT")
    echo "$CLEANED quiet logo.nologo consoleblank=0 cma=256M video=HDMI-A-1:1920x1080M@60" > "${CMDLINE_FILE}"
    echo "   cmdline.txt updated: quiet logo.nologo consoleblank=0 cma=256M video=1920x1080"
fi

# 5b. Copy YUNSH boot scripts + splash to boot partition
echo "→ Copying YUNSH boot files to /boot/"
cp "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "${BOOT_MOUNT}/yunsh-firstboot.sh" 2>/dev/null || true
# Copy firewall & SSH security configs to boot partition
cp "${YUNSH_DIR}/boot/yunsh-iptables.sh" "${BOOT_MOUNT}/yunsh-iptables.sh" 2>/dev/null || true
cp "${YUNSH_DIR}/boot/yunsh-ssh-config.conf" "${BOOT_MOUNT}/yunsh-ssh-config.conf" 2>/dev/null || true
# Copy splash files for framebuffer display (two-phase: logo → logo+text)
echo "→ Copying splash files to /boot/"
for sf in yunsh-splash-logo.raw yunsh-splash-logo.bmp yunsh-splash-full.raw yunsh-splash-full.bmp yunsh-splash-full-720p.bmp; do
    src="${YUNSH_DIR}/build/splash/$sf"
    if [ -f "$src" ]; then
        cp "$src" "${BOOT_MOUNT}/$sf" 2>/dev/null
        echo "   ✓ $sf"
    fi
done

# Unmount boot
sync
umount "${BOOT_MOUNT}" 2>/dev/null || true
# Force detach (multiple attempts in case of hang)
for detach_try in 1 2; do
    hdiutil detach "$BOOT_DEV" 2>/dev/null && break
    [ $detach_try -eq 1 ] && { echo "  Waiting for detach..."; sleep 3; }
done
echo "Boot partition done ✓"

# ════════════════════════════════════════════════════════
# STEP 5b: Write modified boot partition back
# ════════════════════════════════════════════════════════
echo ""
echo "=== Step 5b: Writing boot partition back ==="
BOOT_SIZE_BLOCKS=$((BOOT_END - BOOT_START + 1))
dd if="${BOOT_PARTITION_IMG}" of="${OUTPUT_FILE}" bs=512    seek=$BOOT_START count=$BOOT_SIZE_BLOCKS conv=notrunc 2>/dev/null
sync
echo "Boot partition written back ✓"

# ════════════════════════════════════════════════════════
# STEP 6: Modify ROOT partition (ext4 via debugfs)
# ════════════════════════════════════════════════════════
echo ""
echo "=== Step 6: Injecting YUNSH files into root partition ==="
echo "Tools: ${DEBUGFS}"

# Extract root partition
ROOT_PARTITION_IMG="${BUILD_DIR}/root-partition.img"
dd if="${OUTPUT_FILE}" of="${ROOT_PARTITION_IMG}" bs=512 \
   skip=$ROOT_START count=$((ROOT_END - ROOT_START + 1)) 2>/dev/null
echo "Root partition extracted: $(ls -lh "${ROOT_PARTITION_IMG}")"

# Generate debugfs script
DEBUGFS_SCRIPT="${BUILD_DIR}/yunsh-debugfs.txt"
: > "${DEBUGFS_SCRIPT}"

# Helper: add a write command
add_file() {
    local host_src="$1"
    local dest_path="$2"
    if [ -f "$host_src" ]; then
        echo "write \"${host_src}\" \"${dest_path}\"" >> "${DEBUGFS_SCRIPT}"
    else
        echo "WARN: missing ${host_src}, skipping ${dest_path}"
    fi
}

# Create directory structure
echo "mkdir /usr/share/yunsh" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/ui" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/icons" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/apps" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/logo" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/yunsh" >> "${DEBUGFS_SCRIPT}"

# Inject QML UI files
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH QML UI Files ===" >> "${DEBUGFS_SCRIPT}"
for qml in "${YUNSH_DIR}/ui/"*.qml; do
    fname=$(basename "$qml")
    add_file "$qml" "/usr/share/yunsh/ui/${fname}"
done

# Inject icon files
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH Icon Files ===" >> "${DEBUGFS_SCRIPT}"
for icon in "${YUNSH_DIR}/ui/icons/"*; do
    fname=$(basename "$icon")
    add_file "$icon" "/usr/share/yunsh/icons/${fname}"
done

# Inject logo files
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH Logrotate Config ===" >> "${DEBUGFS_SCRIPT}"
add_file "${YUNSH_DIR}/system/yunsh-logrotate.conf" "/etc/logrotate.d/yunsh"

echo "# === .gitignore ===" >> "${DEBUGFS_SCRIPT}"
add_file "${YUNSH_DIR}/.gitignore" "/root/.gitignore"

echo "# === YUNSH Logo Files ===" >> "${DEBUGFS_SCRIPT}"
for logo in "${YUNSH_DIR}/logo/"*.png; do
    fname=$(basename "$logo")
    add_file "$logo" "/usr/share/yunsh/logo/${fname}"
done

# Inject system scripts → /usr/bin/
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH System Scripts ===" >> "${DEBUGFS_SCRIPT}"
add_file "${YUNSH_DIR}/system/yunsh-update-daemon.py" "/usr/bin/yunsh-update-daemon"
add_file "${YUNSH_DIR}/system/yunsh-updater.py" "/usr/bin/yunsh-updater"
add_file "${YUNSH_DIR}/system/yunsh-network-daemon.py" "/usr/bin/yunsh-network-daemon"
add_file "${YUNSH_DIR}/system/yunsh-bluetooth-daemon.py" "/usr/bin/yunsh-bluetooth-daemon"
add_file "${YUNSH_DIR}/system/yunsh-headtracking" "/usr/bin/yunsh-headtracking"
add_file "${YUNSH_DIR}/system/yunsh-bno085-reader" "/usr/bin/yunsh-bno085-reader"
add_file "${YUNSH_DIR}/system/yunsh-headtracking-sim" "/usr/bin/yunsh-headtracking-sim"
add_file "${YUNSH_DIR}/system/yunsh-screenshotd" "/usr/bin/yunsh-screenshotd"
add_file "${YUNSH_DIR}/system/yunsh-factory-reset" "/usr/bin/yunsh-factory-reset"
add_file "${YUNSH_DIR}/system/yunsh-install-progress.sh" "/usr/bin/yunsh-install-progress.sh"
add_file "${YUNSH_DIR}/system/yunsh-inputd" "/usr/bin/yunsh-inputd"
add_file "${YUNSH_DIR}/system/yunsh-powerd" "/usr/bin/yunsh-powerd"
add_file "${YUNSH_DIR}/system/yunsh-activation-helper" "/usr/bin/yunsh-activation-helper"

# Inject app launcher daemon
add_file "${YUNSH_DIR}/system/yunsh-appd.py" "/usr/bin/yunsh-appd"

# Inject terminal daemon
add_file "${YUNSH_DIR}/system/yunsh-terminal.py" "/usr/bin/yunsh-terminal"

# Inject disk usage helper (for SystemInfo QML)
add_file "${YUNSH_DIR}/system/yunsh-disk-helper" "/usr/bin/yunsh-disk-helper"

# Inject 应用宝 APK (pre-downloaded)
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === 应用宝 APK ===" >> "${DEBUGFS_SCRIPT}"
APK_FILE="${YUNSH_DIR}/build/apps/appstore.apk"
if [ -f "$APK_FILE" ] && [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null)" -gt 1000000 ]; then
    add_file "$APK_FILE" "/usr/share/yunsh/apps/appstore.apk"
    echo "   应用宝 APK 已注入 (real)"
else
    # Create a placeholder - firstboot will try to download
    echo "placeholder" > "${YUNSH_DIR}/build/apps/appstore.apk"
    add_file "${YUNSH_DIR}/build/apps/appstore.apk" "/usr/share/yunsh/apps/appstore.apk"
    echo "   应用宝 APK 占位 (将在首次启动时下载)"
fi

# Copy firstboot to /usr/bin/ too (for fallback)
add_file "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "/usr/bin/yunsh-firstboot.sh"
# Inject iptables script (firewall setup during firstboot)
add_file "${YUNSH_DIR}/boot/yunsh-iptables.sh" "/usr/bin/yunsh-iptables.sh"

# (permissions moved to end of debugfs script)

# ─── Create and inject launcher script ────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH UI Launcher ===" >> "${DEBUGFS_SCRIPT}"
LAUNCHER_FILE="${BUILD_DIR}/yunsh-ui-launcher"
cat > "${LAUNCHER_FILE}" << 'LAUNCHER'
#!/bin/bash
# YUNSH OS v1.0 - UI Launcher (v5)
cd /usr/share/yunsh/ui || { echo "FATAL: UI dir not found"; sleep 30; exit 1; }

QML_RUNNER=$(command -v qml6 || command -v qml || :)

# Phase 1: First boot package installation
if [ ! -f /etc/yunsh/.packages_installed ]; then
    if [ -x /usr/bin/yunsh-firstboot.sh ]; then
        clear 2>/dev/null || true
        /usr/bin/yunsh-firstboot.sh
        touch /etc/yunsh/.packages_installed
        sync
        sleep 2
        reboot
        exit 0
    fi
fi

# Phase 2: Ensure yunsh user exists
if ! id -u yunsh &>/dev/null 2>&1; then
    useradd -m -s /bin/bash yunsh 2>/dev/null || true
    echo "yunsh:yunsh123" | chpasswd 2>/dev/null || true
    usermod -aG sudo,audio,video,input,render yunsh 2>/dev/null || true
fi

# Phase 3: Collect system info
/usr/bin/yunsh-disk-helper 2>/dev/null || true

# Phase 4: Main UI loop
while true; do
    if [ -f /etc/yunsh/.activated ]; then
        $QML_RUNNER main.qml --activated 2>/dev/null
        QML_EXIT=$?
    else
        $QML_RUNNER main.qml --firstboot 2>/dev/null
        QML_EXIT=$?
        if [ $QML_EXIT -eq 42 ]; then
            touch /etc/yunsh/.activated 2>/dev/null
            sync
        fi
    fi
    [ -f /etc/yunsh/.activated ] || touch /etc/yunsh/.activated 2>/dev/null
    sleep 2
done
LAUNCHER
chmod +x "${LAUNCHER_FILE}"
add_file "${LAUNCHER_FILE}" "/usr/bin/yunsh-ui-launcher"

# ─── Create splash script (framebuffer) ────────────
SPLASH_FILE="${BUILD_DIR}/yunsh-splash"
# Use the framebuffer splash from system/ (already written)
cp "${YUNSH_DIR}/system/yunsh-splash" "${SPLASH_FILE}"
chmod +x "${SPLASH_FILE}"
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH Splash ===" >> "${DEBUGFS_SCRIPT}"
add_file "${SPLASH_FILE}" "/usr/bin/yunsh-splash"

# ─── Create factory reset script ──────────────────
# (yunsh-factory-reset already exists in system/)

# ─── Install config files ─────────────────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH Config ===" >> "${DEBUGFS_SCRIPT}"
UPDATE_CONF="${BUILD_DIR}/yunsh-update.conf"
cat > "${UPDATE_CONF}" << 'UC'
# YUNSH OS Update Configuration
auto_update=false
wifi_only=true
update_channel=stable
# update_channel: stable | beta
UC
add_file "${UPDATE_CONF}" "/etc/yunsh/update.conf"

# ─── Version config ──────────────────────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === Version Config ===" >> "${DEBUGFS_SCRIPT}"
VERSION_CONF="${BUILD_DIR}/yunsh-version.conf"
cat > "${VERSION_CONF}" << 'VERCONF'
VERSION=v1.0.1
BUILD=2026.07.12
VERCONF
add_file "${VERSION_CONF}" "/etc/yunsh/version.conf"

# ─── Systemd services ─────────────────────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === YUNSH Systemd Services ===" >> "${DEBUGFS_SCRIPT}"

# Main UI service
# Main UI service — starts on multi-user.target (RPi OS Lite doesn't have graphical.target)
SVC_FILE="${BUILD_DIR}/yunsh-os.service"
cat > "${SVC_FILE}" << 'SVC'
[Unit]
Description=YUNSH OS v1.0 AR Glasses UI
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-ui-launcher
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SVC
echo "mkdir /etc/systemd/system" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/systemd/system/multi-user.target.wants" >> "${DEBUGFS_SCRIPT}"
add_file "${SVC_FILE}" "/etc/systemd/system/yunsh-os.service"

# Enable the service via debugfs symlink
# systemctl enable creates: multi-user.target.wants/yunsh-os.service → ../yunsh-os.service
echo "symlink /etc/systemd/system/multi-user.target.wants/yunsh-os.service ../yunsh-os.service" >> "${DEBUGFS_SCRIPT}"

# Network daemon
NSVC_FILE="${BUILD_DIR}/yunsh-network.service"
cat > "${NSVC_FILE}" << 'NSVC'
[Unit]
Description=YUNSH OS Network Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-network-daemon
Restart=on-failure
RestartSec=15
User=root

[Install]
WantedBy=multi-user.target
NSVC
add_file "${NSVC_FILE}" "/etc/systemd/system/yunsh-network.service"

# Bluetooth daemon
BSVC_FILE="${BUILD_DIR}/yunsh-bluetooth.service"
cat > "${BSVC_FILE}" << 'BSVC'
[Unit]
Description=YUNSH OS Bluetooth Manager
After=bluez.service
Wants=bluez.service

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bluetooth-daemon
Restart=on-failure
RestartSec=15
User=root

[Install]
WantedBy=multi-user.target
BSVC
add_file "${BSVC_FILE}" "/etc/systemd/system/yunsh-bluetooth.service"

# Update daemon
USVC_FILE="${BUILD_DIR}/yunsh-update.service"
cat > "${USVC_FILE}" << 'USVC'
[Unit]
Description=YUNSH OS Update Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/yunsh-update-daemon
Restart=on-failure
RestartSec=30
User=root

[Install]
WantedBy=multi-user.target
USVC
add_file "${USVC_FILE}" "/etc/systemd/system/yunsh-update.service"

# Splash service (early boot logo on framebuffer)
SPLASH_SVC="${BUILD_DIR}/yunsh-splash.service"
cat > "${SPLASH_SVC}" << 'SPLASHSVC'
[Unit]
Description=YUNSH Splash Screen
DefaultDependencies=no
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes
StandardOutput=null
StandardError=null

[Install]
WantedBy=sysinit.target
SPLASHSVC
add_file "${SPLASH_SVC}" "/etc/systemd/system/yunsh-splash.service"
echo "mkdir /etc/systemd/system/sysinit.target.wants" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/sysinit.target.wants/yunsh-splash.service ../yunsh-splash.service" >> "${DEBUGFS_SCRIPT}"

# YUNSH Firewall service (iptables)
FIREWALL_SVC="${BUILD_DIR}/yunsh-firewall.service"
cat > "${FIREWALL_SVC}" << 'FWSVC'
[Unit]
Description=YUNSH OS Firewall (iptables)
Before=network-pre.target
Wants=network-pre.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-iptables.sh
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
FWSVC
add_file "${FIREWALL_SVC}" "/etc/systemd/system/yunsh-firewall.service"

# App Launcher daemon
APPD_SVC="${YUNSH_DIR}/system/yunsh-appd.service"
add_file "${APPD_SVC}" "/etc/systemd/system/yunsh-appd.service"

# Terminal daemon
TERM_SVC="${YUNSH_DIR}/system/yunsh-terminal.service"
add_file "${TERM_SVC}" "/etc/systemd/system/yunsh-terminal.service"

# Head Tracking daemon (3DoF IMU)
HTSVC_FILE="${BUILD_DIR}/yunsh-headtracking.service"
cp "${YUNSH_DIR}/system/yunsh-headtracking.service" "${HTSVC_FILE}"
add_file "${HTSVC_FILE}" "/etc/systemd/system/yunsh-headtracking.service"

# BNO085 IMU reader (direct I2C)
BNO_SVC_FILE="${BUILD_DIR}/yunsh-bno085-reader.service"
cp "${YUNSH_DIR}/system/yunsh-bno085-reader.service" "${BNO_SVC_FILE}"
add_file "${BNO_SVC_FILE}" "/etc/systemd/system/yunsh-bno085-reader.service"

# ─── Auto-login for tty1 ──────────────────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === Auto-login ===" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/systemd/system/getty@tty1.service.d" >> "${DEBUGFS_SCRIPT}"
AUTOLOGIN_FILE="${BUILD_DIR}/yunsh-autologin.conf"
cat > "${AUTOLOGIN_FILE}" << 'AL'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
AL
add_file "${AUTOLOGIN_FILE}" "/etc/systemd/system/getty@tty1.service.d/autologin.conf"

# ─── rc.local (clean fallback — main enable happens in firstboot.sh) ──
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === rc.local cleanup ===" >> "${DEBUGFS_SCRIPT}"
RCLOCAL_FILE="${BUILD_DIR}/yunsh-rc.local"
cat > "${RCLOCAL_FILE}" << 'RCLOCAL'
#!/bin/sh -e
# YUNSH OS - first-boot fallback
exit 0
RCLOCAL
chmod +x "${RCLOCAL_FILE}"
add_file "${RCLOCAL_FILE}" "/etc/rc.local"

# ─── Hostname ─────────────────────────────────────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === Hostname ===" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/hostname" >> "${DEBUGFS_SCRIPT}"
HOSTNAME_FILE="${BUILD_DIR}/yunsh-hostname"
echo "yunsh-v1" > "${HOSTNAME_FILE}"
add_file "${HOSTNAME_FILE}" "/etc/hostname"

# ─── Set executable permissions (must be after all file writes) ──
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === Set executable permissions ===" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-update-daemon mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-updater mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-network-daemon mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-bluetooth-daemon mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-screenshotd mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-factory-reset mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-install-progress.sh mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-inputd mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-powerd mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-firstboot.sh mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-iptables.sh mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-ui-launcher mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-splash mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-appd mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-terminal mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-disk-helper mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-headtracking mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-headtracking-sim mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /usr/bin/yunsh-bno085-reader mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "set_inode_field /etc/rc.local mode 0100755" >> "${DEBUGFS_SCRIPT}"

# ─── Remove RPi OS default first-boot services ────
echo "" >> "${DEBUGFS_SCRIPT}"
echo "# === Remove RPi OS first-boot services ===" >> "${DEBUGFS_SCRIPT}"
# Try to remove; silently ignore if not present
echo "rm /etc/systemd/system/multi-user.target.wants/userconfig.service 2>/dev/null" >> "${DEBUGFS_SCRIPT}"

# ─── Run debugfs ─────────────────────────────────
echo ""
echo "=== Running debugfs injection ==="
echo "Generated $(wc -l < "${DEBUGFS_SCRIPT}") commands"
"${DEBUGFS}" -w -f "${DEBUGFS_SCRIPT}" "${ROOT_PARTITION_IMG}" 2>&1 || {
    echo "DEBUG: debugfs failed. Check ${DEBUGFS_SCRIPT} for commands."
    echo "Manual: ${DEBUGFS} -w ${ROOT_PARTITION_IMG}"
    exit 1
}

echo "debugfs injection complete ✓"

# ─── Run e2fsck to fix filesystem inconsistencies ────
echo ""
echo "=== Running e2fsck ==="
"${E2FSPROGS}/sbin/e2fsck" -fy "${ROOT_PARTITION_IMG}" 2>&1 || true
echo "e2fsck complete ✓"

# ─── Step 7: Write modified root partition back ────
echo ""
echo "=== Step 7: Writing root partition back ==="
ROOT_SIZE_BLOCKS=$((ROOT_END - ROOT_START + 1))
dd if="${ROOT_PARTITION_IMG}" of="${OUTPUT_FILE}" bs=512 \
   seek=$ROOT_START count=$ROOT_SIZE_BLOCKS conv=notrunc 2>/dev/null
sync
echo "Root partition written back ✓"

# ─── Step 8: Cleanup ───────────────────────────────
echo ""
echo "=== Cleanup ==="
rm -f "${BOOT_PARTITION_IMG}" "${ROOT_PARTITION_IMG}" \
      "${LAUNCHER_FILE}" "${SPLASH_FILE}" "${UPDATE_CONF}" \
      "${SVC_FILE}" "${NSVC_FILE}" "${BSVC_FILE}" "${USVC_FILE}" \
      "${SPLASH_SVC}" "${AUTOLOGIN_FILE}" "${RCLOCAL_FILE}" \
      "${HOSTNAME_FILE}" "${DEBUGFS_SCRIPT}"

# ─── Done ──────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ Build complete: ${OUTPUT_FILE}"
echo "============================================"
echo ""
echo "Image size: $(ls -lh "${OUTPUT_FILE}" | awk '{print $5}')"
echo ""
echo "Flash to SD card:"
echo "  sudo dd if=${OUTPUT_FILE} of=/dev/rdisk2 bs=1m status=progress"
echo ""

# Verify injection
echo "=== Quick verification ==="
ROOT_TMP="/tmp/yunsh-root-test"
mkdir -p "${ROOT_TMP}"

# Extract root and check a few files
ROOT_TEST_IMG="${BUILD_DIR}/root-test.img"
dd if="${OUTPUT_FILE}" of="${ROOT_TEST_IMG}" bs=512 \
   skip=$ROOT_START count=$ROOT_SIZE_BLOCKS 2>/dev/null

echo "Files injected:"
"${DEBUGFS}" -R "ls -l /usr/share/yunsh/ui/" "${ROOT_TEST_IMG}" 2>/dev/null | grep -c "\.qml" || echo "  0 QML files (check injection)"
"${DEBUGFS}" -R "ls -l /usr/bin/" "${ROOT_TEST_IMG}" 2>/dev/null | grep -c "yunsh" || echo "  0 yunsh binaries (check injection)"
"${DEBUGFS}" -R "stat /etc/rc.local" "${ROOT_TEST_IMG}" 2>/dev/null | grep -E "Inode|Size" || echo "  rc.local missing"
echo ""
echo "Verify by booting or check via debugfs manually."
rm -f "${ROOT_TEST_IMG}" "${ROOT_TMP}"
