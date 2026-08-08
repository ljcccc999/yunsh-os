#!/bin/bash
# YUNSH OS Image Builder — No hdiutil version
# Uses Python for boot partition (FAT32) manipulation + debugfs for rootfs (ext4)
set -e

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
VERSION_CONF="${BUILD_DIR}/yunsh-version.conf"
if [ ! -f "${VERSION_CONF}" ]; then
    printf 'VERSION=v3.0.0\nBUILD=%s\n' "$(date +%Y.%m.%d)" > "${VERSION_CONF}"
fi
VERSION="$(awk -F= '$1 == "VERSION" { print $2; exit }' "${VERSION_CONF}")"
BUILD_ID="${YUNSH_BUILD_ID:-$(date +%Y.%m.%d)}"
if ! [[ "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.]+)?$ ]]; then
    echo "ERROR: invalid VERSION in ${VERSION_CONF}: ${VERSION}"
    exit 1
fi
OUTPUT_FILE="${OUTPUT_DIR}/YUNSH-OS-${VERSION}.img"
IMAGE_VERSION_CONF="${BUILD_DIR}/yunsh-version-image.conf"
printf 'VERSION=%s\nBUILD=%s\n' "${VERSION}" "${BUILD_ID}" > "${IMAGE_VERSION_CONF}"
# Homebrew upgrades e2fsprogs independently. Resolve its stable prefix instead
# of baking a Cellar version into the image builder.
E2FSPROGS="${YUNSH_E2FSPROGS_PREFIX:-}"
if [ -z "${E2FSPROGS}" ] && command -v brew >/dev/null 2>&1; then
    E2FSPROGS="$(brew --prefix e2fsprogs 2>/dev/null || true)"
fi
if [ ! -x "${E2FSPROGS}/sbin/debugfs" ] || [ ! -x "${E2FSPROGS}/sbin/e2fsck" ]; then
    echo "ERROR: e2fsprogs (debugfs and e2fsck) is required; install it with: brew install e2fsprogs"
    exit 1
fi
DEBUGFS="${E2FSPROGS}/sbin/debugfs"
E2FSCK="${E2FSPROGS}/sbin/e2fsck"

echo "============================================"
echo "  YUNSH OS ${VERSION} - Image Builder (no hdiutil)"
echo "============================================"

# ─── Step 1: Find base image ──────────────────────
RPI_IMAGE="${BUILD_DIR}/raspios-lite.img"
if [ ! -f "$RPI_IMAGE" ]; then
    RPI_IMAGE=$(ls "${BUILD_DIR}"/*raspios*.img 2>/dev/null | head -1 || true)
fi
if [ ! -f "$RPI_IMAGE" ]; then
    echo "ERROR: No RPi OS image found in ${BUILD_DIR}/"
    exit 1
fi
echo "Source: ${RPI_IMAGE} ($(ls -lh "${RPI_IMAGE}" | awk '{print $5}'))"

# ─── Step 2: Parse partition table ────────────────
eval $(python3 << PYEOF
import struct
with open("${RPI_IMAGE}", "rb") as f:
    mbr = f.read(512)
boot_start = struct.unpack_from("<I", mbr, 454)[0]
boot_end = boot_start + struct.unpack_from("<I", mbr, 458)[0] - 1
root_start = struct.unpack_from("<I", mbr, 470)[0]
root_end = root_start + struct.unpack_from("<I", mbr, 474)[0] - 1
print(f"BOOT_START={boot_start} BOOT_END={boot_end}")
print(f"ROOT_START={root_start} ROOT_END={root_end}")
PYEOF
)
BOOT_SIZE=$((BOOT_END - BOOT_START + 1))
ROOT_SIZE=$((ROOT_END - ROOT_START + 1))
echo "Boot: sectors $BOOT_START-$BOOT_END ($BOOT_SIZE sectors)"
echo "Root: sectors $ROOT_START-$ROOT_END ($ROOT_SIZE sectors)"

# ─── Step 3: Create working copy ──────────────────
echo ""
echo "=== Creating working copy ==="
mkdir -p "${OUTPUT_DIR}"
if ! cp -c "${RPI_IMAGE}" "${OUTPUT_FILE}" 2>/dev/null; then
    cp "${RPI_IMAGE}" "${OUTPUT_FILE}"
fi
echo "  ✓ ${OUTPUT_FILE}"

# Ship enough writable root space for the complete desktop.  The stock image
# relies on initramfs + systemd-growfs during the first boot; that job has an
# infinite timeout and is the source of the apparent post-initramfs hang.
# Six GiB remains below the actual capacity of a nominal 8 GB SD card.
MIN_IMAGE_BYTES=$((6 * 1024 * 1024 * 1024))
CURRENT_IMAGE_BYTES=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}")
if [ "${CURRENT_IMAGE_BYTES}" -lt "${MIN_IMAGE_BYTES}" ]; then
    echo "  → Expanding image to 6 GiB for first-boot desktop installation"
    truncate -s "${MIN_IMAGE_BYTES}" "${OUTPUT_FILE}"
    python3 - "${OUTPUT_FILE}" <<'PY'
import struct, sys
with open(sys.argv[1], 'r+b') as fh:
    mbr = bytearray(fh.read(512))
    root_start = struct.unpack_from('<I', mbr, 470)[0]
    sectors = (fh.seek(0, 2) // 512) - root_start
    if not 0 < sectors <= 0xFFFFFFFF:
        raise SystemExit('invalid expanded root partition size')
    struct.pack_into('<I', mbr, 474, sectors)
    fh.seek(0)
    fh.write(mbr)
PY
    ROOT_END=$((MIN_IMAGE_BYTES / 512 - 1))
    ROOT_SIZE=$((ROOT_END - ROOT_START + 1))
fi

# ─── Step 4: Generate splash screens ──────────────
echo ""
echo "=== Generating boot splash screen ==="
python3 "${YUNSH_DIR}/scripts/generate-splash.py"

# ─── Step 5: Download a verified Android app store ──
echo ""
echo "=== Downloading Android app store ==="
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
FDROID_FILE="${BUILD_DIR}/apps/fdroid.apk"
mkdir -p "${BUILD_DIR}/apps"
if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || echo 0)" -lt 1000000 ]; then
    for url in \
        "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
        "https://appdownload.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader.apk"; do
        echo "  Trying: $url"
        curl -L -o "${APK_FILE}" --max-time 30 "$url" 2>/dev/null && break || true
    done
    if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || echo 0)" -lt 100000 ]; then
        rm -f "$APK_FILE"
        echo "  Tencent Appstore unavailable; using F-Droid"
    fi
fi
if [ ! -f "$FDROID_FILE" ] || [ "$(stat -f%z "$FDROID_FILE" 2>/dev/null || echo 0)" -lt 1000000 ]; then
    curl -fL --connect-timeout 15 --max-time 300 \
        -o "${FDROID_FILE}.download" https://f-droid.org/F-Droid.apk
    mv "${FDROID_FILE}.download" "$FDROID_FILE"
fi
python3 - "$FDROID_FILE" <<'PY'
import os, sys, zipfile
p = sys.argv[1]
if os.path.getsize(p) < 1_000_000 or not zipfile.is_zipfile(p):
    raise SystemExit("ERROR: downloaded F-Droid file is not a valid APK")
with zipfile.ZipFile(p) as z:
    if "AndroidManifest.xml" not in z.namelist():
        raise SystemExit("ERROR: APK has no AndroidManifest.xml")
print(f"  ✓ verified APK container ({os.path.getsize(p)} bytes)")
PY

# ─── Step 6: Inject boot partition (mtools) ────────
echo ""
echo "=== Injecting boot partition (mtools) ==="

BOOT_OFFSET=$((BOOT_START * 512))
BOOT_IMG="${BUILD_DIR}/boot-partition-tmp.img"
BOOT_SIZE_BYTES=$((BOOT_SIZE * 512))

# Extract boot partition to temp file
dd if="${OUTPUT_FILE}" of="${BOOT_IMG}" bs=512 skip=$BOOT_START count=$BOOT_SIZE 2>/dev/null
echo "  Boot partition extracted ($((BOOT_SIZE_BYTES / 1024 / 1024)) MB)"

MTOOL="mcopy -i ${BOOT_IMG}"

# Modify config.txt --- extract, modify, write back
echo ""
echo "→ config.txt..."
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null > "${BUILD_DIR}/yunsh-config-new.txt"
KMS_OVERLAY=""
if ! grep -q '^dtoverlay=vc4-kms-v3d' "${BUILD_DIR}/yunsh-config-new.txt"; then
    KMS_OVERLAY="dtoverlay=vc4-kms-v3d"
fi
cat >> "${BUILD_DIR}/yunsh-config-new.txt" << YUNSHCONF

# === YUNSH OS Settings ===
arm_64bit=1
[pi5]
${KMS_OVERLAY}
disable_splash=1
display_auto_detect=1
hdmi_drive=2
hdmi_force_hotplug=1
framebuffer_depth=32
disable_overscan=1
[all]
dtparam=i2c_arm=on
YUNSHCONF
mdel -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/yunsh-config-new.txt" ::/config.txt
echo "  ✓ config.txt modified"

# Modify cmdline.txt
echo ""
echo "→ cmdline.txt..."
mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null > "${BUILD_DIR}/yunsh-cmdline-new.txt"
CMDLINE=$(cat "${BUILD_DIR}/yunsh-cmdline-new.txt")
# Keep a real Linux console on tty1 until the desktop is installed.  The
# original quiet/splash settings could leave a working Pi 5 with HDMI signal
# but no visible first-boot error when the online package install failed.
CMDLINE=$(printf '%s\n' "${CMDLINE}" | sed -E \
    -e 's/(^| )(quiet|splash|logo\.nologo|consoleblank=[^ ]+|loglevel=[^ ]+|systemd\.show_status=[^ ]+|systemd\.log_target=[^ ]+|vt\.global_cursor_default=[^ ]+|cma=[^ ]+)( |$)/ /g' \
    -e 's/(^| )video=HDMI-A-[12]:[^ ]+//g' \
    -e 's/(^| )resize( |$)/ /g' \
    -e 's/  +/ /g')
# Boot from the physical Pi 5 SD-card root partition.  The base image's MBR
# disk signature can change when a card is cloned or rewritten, which makes a
# baked-in root=PARTUUID fail before systemd (and therefore before SSH) starts.
# The release image is SD-card targeted, so use the stable Pi device path and
# keep rootwait to cover card enumeration during early boot.
CMDLINE=$(printf '%s\n' "${CMDLINE}" | sed -E \
    -e 's#(^| )root=PARTUUID=[^ ]+#\1root=/dev/mmcblk0p2#')
case " ${CMDLINE} " in
    *" root=/dev/mmcblk0p2 "*) ;;
    *) CMDLINE="${CMDLINE} root=/dev/mmcblk0p2" ;;
esac
case " ${CMDLINE} " in
    *" console=tty1 "*) ;;
    *) CMDLINE="${CMDLINE} console=tty1" ;;
esac
# Never hide the userspace hand-off on a fresh image.  A Pi that reaches
# init-bottom but cannot start systemd must show its last service, not appear
# frozen on an otherwise healthy rootfs.
echo "${CMDLINE} consoleblank=0 loglevel=4 vt.global_cursor_default=1 cma=256M psi=1 systemd.show_status=1 systemd.log_target=console systemd.log_level=info systemd.default_standard_output=journal+console" > "${BUILD_DIR}/yunsh-cmdline-new.txt"
mdel -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/yunsh-cmdline-new.txt" ::/cmdline.txt
echo "  ✓ cmdline.txt modified"

# Copy YUNSH boot files
echo ""
echo "→ YUNSH boot files..."
mcopy -i "${BOOT_IMG}" "${YUNSH_DIR}/boot/yunsh-firstboot.sh" ::/yunsh-firstboot.sh
echo "  ✓ yunsh-firstboot.sh"
mcopy -i "${BOOT_IMG}" "${YUNSH_DIR}/boot/yunsh-iptables.sh" ::/yunsh-iptables.sh
echo "  ✓ yunsh-iptables.sh"

# Splash files (raw + bmp)
echo "→ Splash files..."
SPLASH_DIR="${BUILD_DIR}/splash"
if [ -d "$SPLASH_DIR" ]; then
  for sf in "$SPLASH_DIR"/*.raw; do
    [ -f "$sf" ] && mcopy -i "${BOOT_IMG}" "$sf" ::/ && echo "  ✓ $(basename $sf)"
  done
  for sf in "$SPLASH_DIR"/*.bmp; do
    [ -f "$sf" ] && mcopy -i "${BOOT_IMG}" "$sf" ::/ && echo "  ✓ $(basename $sf)"
  done
fi

# Write boot partition back to full image
echo ""
echo "→ Writing boot back to output image..."
dd if="${BOOT_IMG}" of="${OUTPUT_FILE}" bs=512 seek=$BOOT_START count=$BOOT_SIZE conv=notrunc 2>/dev/null
sync
# Read the FAT image back before deleting it. These are boot-critical settings:
# a failed mtools write must stop the build rather than becoming an unbootable
# image published under an otherwise valid checksum.
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^dtoverlay=vc4-kms-v3d'
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^hdmi_drive=2'
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^dtparam=i2c_arm=on'
mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'psi=1'
mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'root=/dev/mmcblk0p2'
if mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'root=PARTUUID='; then
    echo "  ✗ Stale PARTUUID root target remains"
    exit 1
fi
mtype -i "${BOOT_IMG}" ::/YUNSH-FIRSTBOOT.SH >/dev/null
rm -f "${BOOT_IMG}" "${BUILD_DIR}/yunsh-config-new.txt" "${BUILD_DIR}/yunsh-cmdline-new.txt"
echo "  ✓ Boot partition written back"

# ─── Step 7: Create debugfs injection script ──────
echo ""
echo "=== Creating debugfs injection script ==="
DEBUGFS_SCRIPT="${BUILD_DIR}/yunsh-debugfs.txt"
>"${DEBUGFS_SCRIPT}"

add_file() {
    local src="$1" dest="$2"
    local size=$(stat -f%z "$src" 2>/dev/null || stat -c%s "$src" 2>/dev/null || echo 0)
    # debugfs `write` refuses to replace an existing inode. Always remove the
    # exact destination first so a reused base cannot silently retain an old
    # launcher, firstboot script, daemon, unit, or configuration file.
    echo "rm ${dest}" >> "${DEBUGFS_SCRIPT}"
    echo "write \"$src\" \"$dest\"" >> "${DEBUGFS_SCRIPT}"
    echo "  $dest ($size bytes)"
}

echo "mkdir /usr/share/yunsh" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/ui" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/icons" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/apps" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/logo" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/yunsh" >> "${DEBUGFS_SCRIPT}"

# A reused base image must never turn a release into an already-installed or
# already-activated system. Remove all boot-state markers before injecting the
# current release; firstboot is the only code allowed to create them.
for stale_state in \
    /etc/yunsh/.packages_installed \
    /etc/yunsh/.activated \
    /etc/yunsh/.firstboot_partial \
    /etc/yunsh/.firewall_configured \
    /etc/yunsh/.ssh_hardened \
    /var/lib/yunsh/.android_ready \
    /var/lib/yunsh/media/.ready \
    /var/lib/yunsh/orbit/voice/.ready; do
    echo "rm ${stale_state}" >> "${DEBUGFS_SCRIPT}"
done

echo "→ QML UI files..."
for qml in "${YUNSH_DIR}/ui/"*.qml; do
    add_file "$qml" "/usr/share/yunsh/ui/$(basename "$qml")"
done

echo "→ Icon files..."
for icon in "${YUNSH_DIR}/ui/icons/"*; do
    [ -f "$icon" ] && add_file "$icon" "/usr/share/yunsh/icons/$(basename "$icon")" || true
done

echo "→ Logo files..."
for logo in "${YUNSH_DIR}/logo/"*.png; do
    [ -f "$logo" ] && add_file "$logo" "/usr/share/yunsh/logo/$(basename "$logo")" || true
done

echo "→ System scripts..."
add_file "${YUNSH_DIR}/system/yunsh-update-daemon.py" "/usr/bin/yunsh-update-daemon"
add_file "${YUNSH_DIR}/system/yunsh-updater.py" "/usr/bin/yunsh-updater"
add_file "${YUNSH_DIR}/system/yunsh-network-daemon.py" "/usr/bin/yunsh-network-daemon"
add_file "${YUNSH_DIR}/system/yunsh-bluetooth-daemon.py" "/usr/bin/yunsh-bluetooth-daemon"
add_file "${YUNSH_DIR}/system/yunsh-link-ble.py" "/usr/bin/yunsh-link-ble"
add_file "${YUNSH_DIR}/system/yunsh-spaced.py" "/usr/bin/yunsh-spaced"
add_file "${YUNSH_DIR}/system/yunsh-screen-relayd.py" "/usr/bin/yunsh-screen-relayd"
add_file "${YUNSH_DIR}/system/yunsh-glasses-bridge.py" "/usr/bin/yunsh-glasses-bridge"
add_file "${YUNSH_DIR}/system/yunsh-headtracking" "/usr/bin/yunsh-headtracking"
add_file "${YUNSH_DIR}/system/yunsh-bno085-reader" "/usr/bin/yunsh-bno085-reader"
add_file "${YUNSH_DIR}/system/yunsh-headtracking-sim" "/usr/bin/yunsh-headtracking-sim"
add_file "${YUNSH_DIR}/system/yunsh-screenshotd" "/usr/bin/yunsh-screenshotd"
add_file "${YUNSH_DIR}/system/yunsh-recordingd" "/usr/bin/yunsh-recordingd"
add_file "${YUNSH_DIR}/system/yunsh-media-setup" "/usr/bin/yunsh-media-setup"
add_file "${YUNSH_DIR}/system/yunsh-grow-root" "/usr/bin/yunsh-grow-root"
add_file "${YUNSH_DIR}/system/yunsh-factory-reset" "/usr/bin/yunsh-factory-reset"
add_file "${YUNSH_DIR}/system/yunsh-install-progress.sh" "/usr/bin/yunsh-install-progress.sh"
add_file "${YUNSH_DIR}/system/yunsh-inputd" "/usr/bin/yunsh-inputd"
add_file "${YUNSH_DIR}/system/yunsh-powerd" "/usr/bin/yunsh-powerd"
add_file "${YUNSH_DIR}/system/yunsh-activation-helper" "/usr/bin/yunsh-activation-helper"
add_file "${YUNSH_DIR}/system/yunsh-appd.py" "/usr/bin/yunsh-appd"
add_file "${YUNSH_DIR}/system/yunsh-android" "/usr/bin/yunsh-android"
add_file "${YUNSH_DIR}/system/yunsh-terminal.py" "/usr/bin/yunsh-terminal"
add_file "${YUNSH_DIR}/system/yunsh-disk-helper" "/usr/bin/yunsh-disk-helper"
add_file "${YUNSH_DIR}/system/orbitd.py" "/usr/bin/orbitd"
add_file "${YUNSH_DIR}/system/orbit-voice-setup" "/usr/bin/orbit-voice-setup"
add_file "${YUNSH_DIR}/system/yunsh-logrotate.conf" "/etc/logrotate.d/yunsh"
add_file "${YUNSH_DIR}/.gitignore" "/root/.gitignore"
add_file "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "/usr/bin/yunsh-firstboot.sh"
add_file "${YUNSH_DIR}/boot/yunsh-iptables.sh" "/usr/bin/yunsh-iptables.sh"

# Android application stores
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
FDROID_FILE="${BUILD_DIR}/apps/fdroid.apk"
if [ -f "$APK_FILE" ] && [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null)" -gt 1000000 ]; then
    add_file "$APK_FILE" "/usr/share/yunsh/apps/appstore.apk"
    echo "  Tencent Appstore APK injected"
fi
add_file "$FDROID_FILE" "/usr/share/yunsh/apps/fdroid.apk"
echo "  F-Droid APK injected (verified fallback)"

# Launcher script
LAUNCHER_FILE="${BUILD_DIR}/yunsh-ui-launcher"
if [ ! -f "${YUNSH_DIR}/system/yunsh-ui-launcher" ]; then
    echo "ERROR: canonical UI launcher is missing"
    exit 1
fi
cp "${YUNSH_DIR}/system/yunsh-ui-launcher" "${LAUNCHER_FILE}"
chmod +x "${LAUNCHER_FILE}"
add_file "${LAUNCHER_FILE}" "/usr/bin/yunsh-ui-launcher"

# Splash script
add_file "${YUNSH_DIR}/system/yunsh-splash" "/usr/bin/yunsh-splash"

# Config files
cat > "${BUILD_DIR}/yunsh-update.conf" << 'UC'
auto_update=false
wifi_only=true
update_channel=stable
UC
add_file "${BUILD_DIR}/yunsh-update.conf" "/etc/yunsh/update.conf"

add_file "${IMAGE_VERSION_CONF}" "/etc/yunsh/version.conf"

# systemd services
echo "mkdir /etc/systemd/system" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/systemd/system/multi-user.target.wants" >> "${DEBUGFS_SCRIPT}"

# Main OS service
cat > "${BUILD_DIR}/yunsh-os.service" << 'SVC'
[Unit]
Description=YUNSH OS Spatial UI
After=network.target yunsh-firstboot.service yunsh-splash.service yunsh-grow-root.service
Wants=network.target yunsh-firstboot.service yunsh-splash.service yunsh-grow-root.service
Conflicts=getty@tty1.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-ui-launcher
Restart=always
RestartSec=2
User=root
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=no
[Install]
WantedBy=multi-user.target
SVC
add_file "${BUILD_DIR}/yunsh-os.service" "/etc/systemd/system/yunsh-os.service"

# First-boot installer: own tty1 explicitly so progress and failures are visible.
cat > "${BUILD_DIR}/yunsh-firstboot.service" << 'FBSVC'
[Unit]
Description=YUNSH OS First Boot Installer
After=network.target yunsh-splash.service yunsh-grow-root.service
Wants=network.target yunsh-splash.service yunsh-grow-root.service
Before=yunsh-os.service
Conflicts=getty@tty1.service
ConditionPathExists=!/etc/yunsh/.packages_installed
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-firstboot.sh
TimeoutStartSec=0
# A transient Wi-Fi/DNS failure must retry setup automatically; requiring a
# manual reboot here was one of the ways a fresh image appeared stuck.
Restart=on-failure
RestartSec=30
# The installer only writes progress; a terminal handoff must not deliver
# SIGHUP when serial/tty getty services start during first boot.
StandardInput=null
StandardOutput=journal+console
StandardError=journal+console
[Install]
WantedBy=multi-user.target
FBSVC
add_file "${BUILD_DIR}/yunsh-firstboot.service" "/etc/systemd/system/yunsh-firstboot.service"

cat > "${BUILD_DIR}/yunsh-grow-root.service" << 'GROWSVC'
[Unit]
Description=YUNSH Grow Root Filesystem to SD Card
After=local-fs.target
Before=yunsh-firstboot.service yunsh-os.service
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-grow-root
TimeoutStartSec=180
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
GROWSVC
add_file "${BUILD_DIR}/yunsh-grow-root.service" "/etc/systemd/system/yunsh-grow-root.service"

cat > "${BUILD_DIR}/yunsh-local-api.service" << 'APISVC'
[Unit]
Description=YUNSH OS Local QML API Bridge
After=yunsh-network.service yunsh-bluetooth.service yunsh-update.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-activation-helper
Restart=always
RestartSec=2
User=root
[Install]
WantedBy=multi-user.target
APISVC
add_file "${BUILD_DIR}/yunsh-local-api.service" "/etc/systemd/system/yunsh-local-api.service"

cat > "${BUILD_DIR}/yunsh-spaced.service" << 'SPACESVC'
[Unit]
Description=YUNSH Drop Encrypted Nearby Workspace Receiver
After=network-online.target avahi-daemon.service
Wants=network-online.target avahi-daemon.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-spaced
Restart=always
RestartSec=3
User=root
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/etc/yunsh /var/lib/yunsh/space-inbox
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
SPACESVC
add_file "${BUILD_DIR}/yunsh-spaced.service" "/etc/systemd/system/yunsh-spaced.service"

cat > "${BUILD_DIR}/yunsh-screen-relay.service" << 'RELAYDSVC'
[Unit]
Description=YUNSH Encrypted iPhone Screen Relay
After=yunsh-spaced.service network-online.target avahi-daemon.service
Requires=yunsh-spaced.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-screen-relayd
Restart=always
RestartSec=3
User=root
PrivateTmp=true
ProtectSystem=strict
ReadOnlyPaths=/etc/yunsh
ReadWritePaths=/run/yunsh
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
RELAYDSVC
add_file "${BUILD_DIR}/yunsh-screen-relay.service" "/etc/systemd/system/yunsh-screen-relay.service"

# Network service
cat > "${BUILD_DIR}/yunsh-network.service" << 'NSVC'
[Unit]
Description=YUNSH OS Network Manager
After=NetworkManager.service
BindsTo=NetworkManager.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-network-daemon
Restart=always
[Install]
WantedBy=multi-user.target
NSVC
add_file "${BUILD_DIR}/yunsh-network.service" "/etc/systemd/system/yunsh-network.service"

# Bluetooth service
cat > "${BUILD_DIR}/yunsh-bluetooth.service" << 'BSVC'
[Unit]
Description=YUNSH OS Bluetooth Manager
After=bluetooth.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bluetooth-daemon
Restart=always
User=root
[Install]
WantedBy=multi-user.target
BSVC
add_file "${BUILD_DIR}/yunsh-bluetooth.service" "/etc/systemd/system/yunsh-bluetooth.service"

# Bluetooth companion service for YUNSH Link on iPhone
cat > "${BUILD_DIR}/yunsh-link-ble.service" << 'LINKSVC'
[Unit]
Description=YUNSH Link Bluetooth Companion
After=bluetooth.service yunsh-update.service
Wants=bluetooth.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-link-ble
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
LINKSVC
add_file "${BUILD_DIR}/yunsh-link-ble.service" "/etc/systemd/system/yunsh-link-ble.service"

cat > "${BUILD_DIR}/yunsh-glasses-bridge.service" << 'GLASSESSVC'
[Unit]
Description=YUNSH V1 Glasses Bluetooth Bridge
After=bluetooth.service yunsh-bluetooth.service yunsh-headtracking.service
Wants=bluetooth.service yunsh-headtracking.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-glasses-bridge
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
GLASSESSVC
add_file "${BUILD_DIR}/yunsh-glasses-bridge.service" "/etc/systemd/system/yunsh-glasses-bridge.service"

# Update service
cat > "${BUILD_DIR}/yunsh-update.service" << 'USVC'
[Unit]
Description=YUNSH OS OTA Update Daemon
After=network-online.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-update-daemon --foreground
Restart=always
User=root
[Install]
WantedBy=multi-user.target
USVC
add_file "${BUILD_DIR}/yunsh-update.service" "/etc/systemd/system/yunsh-update.service"

# App daemon service
cat > "${BUILD_DIR}/yunsh-appd.service" << 'APPSVC'
[Unit]
Description=YUNSH OS App Launcher Daemon
After=network.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-appd
Restart=always
[Install]
WantedBy=multi-user.target
APPSVC
add_file "${BUILD_DIR}/yunsh-appd.service" "/etc/systemd/system/yunsh-appd.service"

# Orbit is a system runtime, but it is deliberately independent from the UI.
# A provider, package, microphone, or network failure must never block desktop.
cat > "${BUILD_DIR}/orbit.service" << 'ORBITSVC'
[Unit]
Description=Orbit System Agent Runtime
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/orbitd
Restart=always
RestartSec=10
User=root
UMask=0077
[Install]
WantedBy=multi-user.target
ORBITSVC
add_file "${BUILD_DIR}/orbit.service" "/etc/systemd/system/orbit.service"

cat > "${BUILD_DIR}/orbit-voice-setup.service" << 'ORBITVOICESVC'
[Unit]
Description=Orbit Optional Voice Runtime Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/yunsh/.packages_installed
ConditionPathExists=!/var/lib/yunsh/orbit/voice/.ready
[Service]
Type=oneshot
ExecStart=/usr/bin/orbit-voice-setup
TimeoutStartSec=1800
Restart=on-failure
RestartSec=120
Nice=10
IOSchedulingClass=idle
[Install]
WantedBy=multi-user.target
ORBITVOICESVC
add_file "${BUILD_DIR}/orbit-voice-setup.service" "/etc/systemd/system/orbit-voice-setup.service"

cat > "${BUILD_DIR}/yunsh-media-setup.service" << 'MEDIASVC'
[Unit]
Description=YUNSH Optional Screen Recording and OCR Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/yunsh/.packages_installed
ConditionPathExists=!/var/lib/yunsh/media/.ready
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-media-setup
TimeoutStartSec=1800
Restart=on-failure
RestartSec=120
Nice=10
[Install]
WantedBy=multi-user.target
MEDIASVC
add_file "${BUILD_DIR}/yunsh-media-setup.service" "/etc/systemd/system/yunsh-media-setup.service"

# Android runtime setup is deliberately independent of yunsh-os.service.
# A slow/unavailable Android image server must never prevent the desktop from
# reaching activation. This service retries in the background after firstboot.
cat > "${BUILD_DIR}/yunsh-android-setup.service" << 'ANDROIDSVC'
[Unit]
Description=YUNSH OS Android Runtime Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/yunsh/.packages_installed
ConditionPathExists=!/var/lib/yunsh/.android_ready
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-android setup
TimeoutStartSec=1900
Restart=on-failure
RestartSec=120
[Install]
WantedBy=multi-user.target
ANDROIDSVC
add_file "${BUILD_DIR}/yunsh-android-setup.service" "/etc/systemd/system/yunsh-android-setup.service"

# Splash service
cat > "${BUILD_DIR}/yunsh-splash.service" << 'SSVC'
[Unit]
Description=YUNSH OS Boot Splash
After=local-fs.target
Before=yunsh-firstboot.service yunsh-os.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
SSVC
add_file "${BUILD_DIR}/yunsh-splash.service" "/etc/systemd/system/yunsh-splash.service"

# Firewall service
cat > "${BUILD_DIR}/yunsh-firewall.service" << 'FSVC'
[Unit]
Description=YUNSH OS Firewall (iptables)
Before=network-pre.target
Wants=network-pre.target
DefaultDependencies=no
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-iptables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
FSVC
add_file "${BUILD_DIR}/yunsh-firewall.service" "/etc/systemd/system/yunsh-firewall.service"

# Head tracking service
cat > "${BUILD_DIR}/yunsh-headtracking.service" << 'HTSVC'
[Unit]
Description=YUNSH OS Head Tracking
After=local-fs.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-headtracking
Restart=always
[Install]
WantedBy=multi-user.target
HTSVC
add_file "${BUILD_DIR}/yunsh-headtracking.service" "/etc/systemd/system/yunsh-headtracking.service"

# BNO085 reader service
cat > "${BUILD_DIR}/yunsh-bno085-reader.service" << 'BNOSVC'
[Unit]
Description=YUNSH OS BNO085 IMU Reader
After=local-fs.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bno085-reader
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
BNOSVC
add_file "${BUILD_DIR}/yunsh-bno085-reader.service" "/etc/systemd/system/yunsh-bno085-reader.service"

cat > "${BUILD_DIR}/yunsh-powerd.service" << 'POWERSVC'
[Unit]
Description=YUNSH OS Power Manager
After=local-fs.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-powerd
Restart=on-failure
[Install]
WantedBy=multi-user.target
POWERSVC
add_file "${BUILD_DIR}/yunsh-powerd.service" "/etc/systemd/system/yunsh-powerd.service"

# Terminal service
cat > "${BUILD_DIR}/yunsh-terminal.service" << 'TERMSVC'
[Unit]
Description=YUNSH OS Terminal Daemon (PTY bash)
After=network.target yunsh-os.service
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-terminal
Restart=on-failure
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
TERMSVC
add_file "${BUILD_DIR}/yunsh-terminal.service" "/etc/systemd/system/yunsh-terminal.service"

# Enable services
for service in yunsh-os yunsh-firstboot yunsh-grow-root yunsh-local-api yunsh-spaced yunsh-screen-relay yunsh-network yunsh-bluetooth \
               yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-appd yunsh-android-setup yunsh-terminal yunsh-headtracking \
               yunsh-powerd yunsh-splash yunsh-media-setup orbit orbit-voice-setup; do
    echo "rm /etc/systemd/system/multi-user.target.wants/${service}.service" >> "${DEBUGFS_SCRIPT}"
    echo "symlink /etc/systemd/system/multi-user.target.wants/${service}.service ../${service}.service" >> "${DEBUGFS_SCRIPT}"
done
# Network: disable dhcpcd, enable NetworkManager + fstrim
echo "rm /etc/systemd/system/multi-user.target.wants/dhcpcd.service" >> "${DEBUGFS_SCRIPT}"
# The filesystem is grown while building the image. Removing one wants-link is
# insufficient on current Raspberry Pi OS: first-boot generators can still
# enqueue both resize units and stall sysinit. Mask them explicitly.
echo "rm /etc/systemd/system/sysinit.target.wants/rpi-resize.service" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/rpi-resize.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/rpi-resize.service /dev/null" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/rpi-resize-swap-file.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/rpi-resize-swap-file.service /dev/null" >> "${DEBUGFS_SCRIPT}"
# Raspberry Pi OS can recreate the stock user-configuration wants-link during
# boot.  Its whiptail dialog owns tty8 and keeps multi-user/graphical.target in
# the starting state forever on a headless YUNSH image.  YUNSH has its own
# first-boot/account flow, so mask the unit itself.  NetworkManager is the only
# network manager in this image; the systemd-networkd waiter otherwise burns
# 120 seconds on every boot waiting for a daemon that is intentionally unused.
echo "rm /etc/systemd/system/userconfig.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/userconfig.service /dev/null" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/systemd-networkd-wait-online.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/systemd-networkd-wait-online.service /dev/null" >> "${DEBUGFS_SCRIPT}"

# Keep the stock tty1 getty. The first-boot service owns tty1 while installing,
# avoiding a race with auto-login before the yunsh user has been created.

# rc.local
RCLOCAL_FILE="${BUILD_DIR}/yunsh-rc-local"
cat > "${RCLOCAL_FILE}" << 'RCLOCAL'
#!/bin/sh
# YUNSH OS - Late init
modprobe i2c-dev 2>/dev/null || true
exit 0
RCLOCAL
chmod +x "${RCLOCAL_FILE}"
add_file "${RCLOCAL_FILE}" "/etc/rc.local"

# Hostname
echo "rm /etc/hostname" >> "${DEBUGFS_SCRIPT}"
echo "yunsh-v1" > "${BUILD_DIR}/yunsh-hostname"
add_file "${BUILD_DIR}/yunsh-hostname" "/etc/hostname"
# Keep the configured hostname locally resolvable.  Without this entry every
# sudo call emits a resolver warning, and services which resolve their own
# hostname can pause on DNS during the first boot.
cat > "${BUILD_DIR}/yunsh-hosts" << 'HOSTS'
127.0.0.1 localhost
127.0.1.1 yunsh-v1
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTS
add_file "${BUILD_DIR}/yunsh-hosts" "/etc/hosts"

# Set permissions
for bin in yunsh-update-daemon yunsh-updater yunsh-network-daemon yunsh-bluetooth-daemon \
           yunsh-link-ble yunsh-spaced yunsh-screen-relayd \
           yunsh-glasses-bridge \
           yunsh-screenshotd yunsh-factory-reset yunsh-install-progress.sh yunsh-inputd \
           yunsh-powerd yunsh-firstboot.sh yunsh-iptables.sh yunsh-ui-launcher yunsh-splash \
           yunsh-appd yunsh-terminal yunsh-disk-helper yunsh-headtracking yunsh-headtracking-sim \
           yunsh-bno085-reader yunsh-activation-helper yunsh-android yunsh-recordingd yunsh-media-setup yunsh-grow-root orbitd orbit-voice-setup; do
    echo "set_inode_field /usr/bin/${bin} mode 0100755" >> "${DEBUGFS_SCRIPT}"
done
echo "set_inode_field /etc/rc.local mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/multi-user.target.wants/userconfig.service" >> "${DEBUGFS_SCRIPT}"

# ─── Step 8: Run debugfs on rootfs ────────────────
echo ""
echo "=== Extracting root partition ==="
ROOT_PARTITION_IMG="${BUILD_DIR}/root-partition.img"
rm -f "${ROOT_PARTITION_IMG}"
dd if="${OUTPUT_FILE}" of="${ROOT_PARTITION_IMG}" bs=512 \
   skip=$ROOT_START count=$ROOT_SIZE 2>/dev/null
echo "  ✓ root partition extracted ($((ROOT_SIZE * 512 / 1024 / 1024)) MB)"

# Grow ext4 now, before any YUNSH files are injected.  This makes the SD card
# immediately usable and removes the fragile first-boot growfs dependency.
"${E2FSCK}" -fy "${ROOT_PARTITION_IMG}" >/dev/null
"${E2FSPROGS}/sbin/resize2fs" "${ROOT_PARTITION_IMG}" >/dev/null

echo ""
echo "=== Running debugfs injection ==="
echo "Commands: $(wc -l < "${DEBUGFS_SCRIPT}")"
"${DEBUGFS}" -w -f "${DEBUGFS_SCRIPT}" "${ROOT_PARTITION_IMG}" 2>&1 || {
    echo "DEBUG: debugfs failed!"
    exit 1
}
echo "debugfs injection ✓"

# ─── Step 9: e2fsck ────────────────────────────────
echo ""
echo "=== Running e2fsck ==="
set +e
"${E2FSCK}" -fy "${ROOT_PARTITION_IMG}" 2>&1
FSCK_RESULT=$?
set -e
if [ "${FSCK_RESULT}" -gt 1 ]; then
    echo "ERROR: e2fsck failed with status ${FSCK_RESULT}"
    exit "${FSCK_RESULT}"
fi
echo "e2fsck ✓"

# ─── Step 10: Write root back ─────────────────────
echo ""
echo "=== Writing root partition back ==="
dd if="${ROOT_PARTITION_IMG}" of="${OUTPUT_FILE}" bs=512 \
   seek=$ROOT_START count=$ROOT_SIZE conv=notrunc 2>/dev/null
sync
echo "Root partition written ✓"

# ─── Step 11: Verify ─────────────────────────────
echo ""
echo "=== Quick verification ==="
# Extract root and check files
ROOT_TEST_IMG="${BUILD_DIR}/root-test.img"
dd if="${OUTPUT_FILE}" of="${ROOT_TEST_IMG}" bs=512 \
   skip=$ROOT_START count=$ROOT_SIZE 2>/dev/null

echo "Files injected:"
"${E2FSPROGS}/sbin/debugfs" -R "ls -l /usr/bin/yunsh" "${ROOT_TEST_IMG}" 2>/dev/null | head -5 || true
"${E2FSPROGS}/sbin/debugfs" -R "ls -l /usr/share/yunsh/ui" "${ROOT_TEST_IMG}" 2>/dev/null | head -5 || true
echo "(partial listing, see build log for complete)"

REQUIRED_ROOT_FILES="
/usr/bin/yunsh-ui-launcher
/usr/bin/yunsh-firstboot.sh
/usr/bin/yunsh-grow-root
/usr/bin/growpart
/usr/sbin/resize2fs
/usr/bin/yunsh-activation-helper
/usr/bin/yunsh-network-daemon
/usr/bin/yunsh-bluetooth-daemon
/usr/bin/yunsh-update-daemon
/usr/bin/yunsh-updater
/usr/bin/yunsh-link-ble
/usr/bin/yunsh-glasses-bridge
/usr/bin/yunsh-headtracking
/usr/bin/yunsh-android
/usr/bin/orbitd
/usr/bin/orbit-voice-setup
/usr/bin/yunsh-recordingd
/usr/bin/yunsh-media-setup
/usr/share/yunsh/ui/main.qml
/usr/share/yunsh/ui/HomeScreen.qml
/usr/share/yunsh/ui/OrbitPanel.qml
/usr/share/yunsh/ui/SystemMenuBar.qml
/usr/share/yunsh/icons/orbit.png
/usr/share/yunsh/logo/logo-256.png
/etc/yunsh/version.conf
/etc/systemd/system/yunsh-os.service
/etc/systemd/system/yunsh-firstboot.service
/etc/systemd/system/yunsh-grow-root.service
/etc/systemd/system/yunsh-android-setup.service
/etc/systemd/system/orbit.service
/etc/systemd/system/orbit-voice-setup.service
/etc/systemd/system/yunsh-media-setup.service
/etc/systemd/system/rpi-resize.service
/etc/systemd/system/rpi-resize-swap-file.service
/etc/systemd/system/userconfig.service
/etc/systemd/system/systemd-networkd-wait-online.service
/etc/systemd/system/multi-user.target.wants/yunsh-os.service
/etc/systemd/system/multi-user.target.wants/yunsh-firstboot.service
/etc/systemd/system/multi-user.target.wants/yunsh-grow-root.service
/etc/systemd/system/multi-user.target.wants/yunsh-android-setup.service
/etc/systemd/system/multi-user.target.wants/orbit.service
/etc/systemd/system/multi-user.target.wants/orbit-voice-setup.service
/etc/systemd/system/multi-user.target.wants/yunsh-media-setup.service
"
for required in ${REQUIRED_ROOT_FILES}; do
    if ! "${E2FSPROGS}/sbin/debugfs" -R "stat ${required}" "${ROOT_TEST_IMG}" 2>&1 |
        grep -q '^Inode:'; then
        echo "ERROR: required image file is missing: ${required}"
        exit 1
    fi
done

FORBIDDEN_ROOT_STATE="
/etc/yunsh/.packages_installed
/etc/yunsh/.activated
/etc/yunsh/.firstboot_partial
/etc/yunsh/.firewall_configured
/etc/yunsh/.ssh_hardened
/var/lib/yunsh/.android_ready
/var/lib/yunsh/media/.ready
/var/lib/yunsh/orbit/voice/.ready
"
for forbidden in ${FORBIDDEN_ROOT_STATE}; do
    if "${E2FSPROGS}/sbin/debugfs" -R "stat ${forbidden}" "${ROOT_TEST_IMG}" 2>&1 |
        grep -q '^Inode:'; then
        echo "ERROR: release image contains stale runtime state: ${forbidden}"
        exit 1
    fi
done
set +e
"${E2FSCK}" -fn "${ROOT_TEST_IMG}" >/dev/null 2>&1
FSCK_VERIFY=$?
set -e
if [ "${FSCK_VERIFY}" -gt 1 ]; then
    echo "ERROR: final root filesystem verification failed (${FSCK_VERIFY})"
    exit "${FSCK_VERIFY}"
fi
echo "  ✓ Required files and clean first-boot state verified"

# Cleanup
rm -f "${ROOT_PARTITION_IMG}" "${ROOT_TEST_IMG}" "${LAUNCHER_FILE}" "${DEBUGFS_SCRIPT}" "${IMAGE_VERSION_CONF}"

# ─── Step 12: Compress ───────────────────────────
echo ""
echo "=== Compressing ==="
xz -v -f "${OUTPUT_FILE}" 2>&1
xz -t "${OUTPUT_FILE}.xz"
(
    cd "${OUTPUT_DIR}"
    shasum -a 256 "$(basename "${OUTPUT_FILE}.xz")" \
        > "$(basename "${OUTPUT_FILE}.xz.sha256")"
)
"${YUNSH_DIR}/scripts/build-ota.sh"
echo ""
echo "============================================"
echo "  ✅ Build complete!"
echo "============================================"
echo ""
echo "Output: ${OUTPUT_FILE}.xz"
echo "Size: $(ls -lh "${OUTPUT_FILE}.xz" | awk '{print $5}')"
echo ""
echo "Flash to SD card:"
echo "  xz -dc ${OUTPUT_FILE}.xz | sudo dd of=/dev/rdisk2 bs=1m"
