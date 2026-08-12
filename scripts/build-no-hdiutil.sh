#!/bin/bash
# YUNSH OS Image Builder — No hdiutil version
# Uses Python for boot partition (FAT32) manipulation + debugfs for rootfs (ext4)
set -e

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
VERSION_CONF="${BUILD_DIR}/yunsh-version.conf"
if [ ! -f "${VERSION_CONF}" ]; then
    printf 'VERSION=v4.0\nBUILD=%s\n' "$(date +%Y.%m.%d)" > "${VERSION_CONF}"
fi
VERSION="$(awk -F= '$1 == "VERSION" { print $2; exit }' "${VERSION_CONF}")"
BUILD_ID="${YUNSH_BUILD_ID:-$(date +%Y.%m.%d)}"
if ! [[ "${VERSION}" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?([.-][A-Za-z0-9.]+)?$ ]]; then
    echo "ERROR: invalid VERSION in ${VERSION_CONF}: ${VERSION}"
    exit 1
fi

# Boot firmware layers are device-specific. The current release foundation is
# Raspberry Pi 5; another target must be implemented with its own base image
# and firmware layer before any image bytes are created.
TARGET_DEVICE="${YUNSH_TARGET_DEVICE:-raspberry-pi-5}"
case "${TARGET_DEVICE}" in
    pi5|raspberry-pi-5)
        TARGET_DEVICE="raspberry-pi-5"
        PERSISTENT_BOOT_FIRMWARE_DIR="${YUNSH_DIR}/../../启动固件层/Raspberry Pi 5"
        LEGACY_BOOT_FIRMWARE_DIR="${BUILD_DIR}/pi5-boot-confirmed"
        ;;
    *)
        echo "ERROR: no device foundation is configured for ${TARGET_DEVICE}."
        echo "Prepare that device's base image and boot firmware layer before building."
        exit 1
        ;;
esac

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
echo "=== Preparing F-Droid Android app store ==="
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
FDROID_FILE="${BUILD_DIR}/apps/fdroid.apk"
mkdir -p "${BUILD_DIR}/apps"
if [ "${YUNSH_USE_TENCENT_APPSTORE:-0}" != "1" ]; then
    YUNSH_INCLUDE_FDROID_FALLBACK=1
fi
if [ "${YUNSH_USE_TENCENT_APPSTORE:-0}" = "1" ]; then
if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null || echo 0)" -lt 1000000 ]; then
    for url in \
        "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
        "https://appdownload.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader.apk"; do
        echo "  Trying: $url"
        curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 \
            -o "${APK_FILE}.download" --max-time 300 "$url" 2>/dev/null && {
            mv "${APK_FILE}.download" "${APK_FILE}"
            break
        } || true
    done
    if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null || echo 0)" -lt 100000 ]; then
        rm -f "$APK_FILE"
        echo "  Tencent Appstore unavailable"
        if [ "${YUNSH_ALLOW_FDROID_FALLBACK:-0}" = "1" ]; then
            YUNSH_INCLUDE_FDROID_FALLBACK=1
            echo "  Using F-Droid as the configured Android app store"
        else
            echo "ERROR: Tencent Appstore was explicitly requested but is unavailable"
            echo "Remove YUNSH_USE_TENCENT_APPSTORE=1 to use the default F-Droid store."
            exit 1
        fi
    fi
fi
fi
if [ "${YUNSH_INCLUDE_FDROID_FALLBACK:-0}" = "1" ] &&
   { [ ! -f "$FDROID_FILE" ] || [ "$(stat -f%z "$FDROID_FILE" 2>/dev/null || stat -c%s "$FDROID_FILE" 2>/dev/null || echo 0)" -lt 1000000 ]; }; then
    curl -fL --connect-timeout 15 --max-time 300 \
        -o "${FDROID_FILE}.download" https://f-droid.org/F-Droid.apk
    mv "${FDROID_FILE}.download" "$FDROID_FILE"
fi
if [ "${YUNSH_INCLUDE_FDROID_FALLBACK:-0}" = "1" ]; then
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
fi

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

# Select the persistent, device-specific boot layer. It contains no settings,
# activation, pairing, or runtime state.
if [ -n "${YUNSH_BOOT_FIRMWARE_DIR:-}" ]; then
    CONFIRMED_BOOT_DIR="${YUNSH_BOOT_FIRMWARE_DIR}"
elif [ -n "${YUNSH_CONFIRMED_BOOT_DIR:-}" ]; then
    # Compatibility with the previous environment variable.
    CONFIRMED_BOOT_DIR="${YUNSH_CONFIRMED_BOOT_DIR}"
elif [ -d "${PERSISTENT_BOOT_FIRMWARE_DIR}" ]; then
    CONFIRMED_BOOT_DIR="${PERSISTENT_BOOT_FIRMWARE_DIR}"
elif [ -d "${LEGACY_BOOT_FIRMWARE_DIR}" ]; then
    CONFIRMED_BOOT_DIR="${LEGACY_BOOT_FIRMWARE_DIR}"
else
    echo "ERROR: missing boot firmware layer for ${TARGET_DEVICE}."
    echo "Expected: ${PERSISTENT_BOOT_FIRMWARE_DIR}"
    exit 1
fi

if [ -f "${CONFIRMED_BOOT_DIR}/DEVICE.conf" ]; then
    LAYER_DEVICE_ID="$(awk -F= '$1 == "DEVICE_ID" {print $2; exit}' "${CONFIRMED_BOOT_DIR}/DEVICE.conf")"
    if [ "${LAYER_DEVICE_ID}" != "${TARGET_DEVICE}" ]; then
        echo "ERROR: firmware layer targets ${LAYER_DEVICE_ID:-unknown}, not ${TARGET_DEVICE}."
        exit 1
    fi
fi
for required_firmware in \
    kernel_2712.img \
    initramfs_2712 \
    bcm2712-rpi-5-b.dtb \
    overlays/vc4-kms-v3d-pi5.dtbo; do
    if [ ! -f "${CONFIRMED_BOOT_DIR}/${required_firmware}" ]; then
        echo "ERROR: incomplete ${TARGET_DEVICE} firmware layer: ${required_firmware}"
        exit 1
    fi
done
if [ -f "${CONFIRMED_BOOT_DIR}/SHA256SUMS" ]; then
    (
        cd "${CONFIRMED_BOOT_DIR}"
        shasum -a 256 -c SHA256SUMS >/dev/null
    ) || {
        echo "ERROR: boot firmware layer checksum verification failed."
        exit 1
    }
fi

# A boot layer is only safe when its kernel/initramfs ABI matches the clean
# Raspberry Pi OS rootfs used by this build.  Mixing a newer confirmed kernel
# with older /lib/modules lets Linux start but leaves KMS, Wi-Fi and other
# drivers unavailable after the root switch.  In that case keep the archived
# layer untouched and use the base image's internally matched Pi 5 stack.
BASE_INITRAMFS_CHECK="${BUILD_DIR}/base-initramfs-check"
mdel -i "${BOOT_IMG}" ::/BASE-INITRAMFS-CHECK 2>/dev/null || true
mcopy -i "${BOOT_IMG}" ::/initramfs_2712 "${BASE_INITRAMFS_CHECK}"
initramfs_kernel_version() {
    strings "$1" 2>/dev/null |
        sed -nE 's#.*usr/lib/modules/([^/[:space:]]+).*#\1#p' |
        head -1
}
BASE_KERNEL_ABI="$(initramfs_kernel_version "${BASE_INITRAMFS_CHECK}")"
LAYER_KERNEL_ABI="$(initramfs_kernel_version "${CONFIRMED_BOOT_DIR}/initramfs_2712")"
rm -f "${BASE_INITRAMFS_CHECK}"
[ -n "${BASE_KERNEL_ABI}" ] || {
    echo "ERROR: cannot determine base image Pi 5 kernel ABI."
    exit 1
}
[ -n "${LAYER_KERNEL_ABI}" ] || {
    echo "ERROR: cannot determine confirmed boot layer kernel ABI."
    exit 1
}
APPLY_CONFIRMED_BOOT_LAYER=1
if [ "${BASE_KERNEL_ABI}" != "${LAYER_KERNEL_ABI}" ]; then
    APPLY_CONFIRMED_BOOT_LAYER=0
    echo "  ⚠ Boot layer ABI ${LAYER_KERNEL_ABI} does not match rootfs ABI ${BASE_KERNEL_ABI}."
    echo "  ✓ Preserving the clean base image's matched kernel, initramfs, DTBs and modules."
fi

copy_confirmed_boot_file() {
    local source_file="$1"
    local target_file="$2"
    [ -f "$source_file" ] || return 0
    mdel -i "${BOOT_IMG}" "::/${target_file}" 2>/dev/null || true
    mcopy -i "${BOOT_IMG}" "$source_file" "::/${target_file}"
}
if [ "${APPLY_CONFIRMED_BOOT_LAYER}" -eq 1 ]; then
    echo "→ Applying ${TARGET_DEVICE} boot firmware layer (no settings or runtime state)..."
    for source_file in \
        "${CONFIRMED_BOOT_DIR}"/kernel*.img \
        "${CONFIRMED_BOOT_DIR}"/initramfs* \
        "${CONFIRMED_BOOT_DIR}"/*.dtb \
        "${CONFIRMED_BOOT_DIR}"/*.elf \
        "${CONFIRMED_BOOT_DIR}"/*.dat \
        "${CONFIRMED_BOOT_DIR}"/bootcode.bin \
        "${CONFIRMED_BOOT_DIR}"/LICENCE.broadcom; do
        [ -f "$source_file" ] || continue
        copy_confirmed_boot_file "$source_file" "$(basename "$source_file")"
    done
    for source_file in \
        "${CONFIRMED_BOOT_DIR}"/overlays/README \
        "${CONFIRMED_BOOT_DIR}"/overlays/overlay_map.dtb \
        "${CONFIRMED_BOOT_DIR}"/overlays/*.dtbo; do
        [ -f "$source_file" ] || continue
        copy_confirmed_boot_file "$source_file" "overlays/$(basename "$source_file")"
    done
    echo "  ✓ Confirmed firmware payload applied"
fi

# Modify config.txt --- extract, modify, write back
echo ""
echo "→ config.txt..."
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null > "${BUILD_DIR}/yunsh-config-new.txt"
# Preserve the VC4 overlay selected by the matched boot stack. Raspberry Pi
# OS uses the generic overlay and maps it to the Pi 5 implementation; a
# confirmed, ABI-matched layer may provide the explicit -pi5 overlay.
if ! grep -q '^disable_fw_kms_setup=1$' "${BUILD_DIR}/yunsh-config-new.txt"; then
    sed -i '' -e '/^auto_initramfs=1$/a\
disable_fw_kms_setup=1' "${BUILD_DIR}/yunsh-config-new.txt" 2>/dev/null ||
    sed -i -e '/^auto_initramfs=1$/a disable_fw_kms_setup=1' "${BUILD_DIR}/yunsh-config-new.txt"
fi
KMS_OVERLAY=""
if ! grep -Eq '^dtoverlay=vc4-kms-v3d(-pi5)?([,[:space:]]|$)' "${BUILD_DIR}/yunsh-config-new.txt"; then
    KMS_OVERLAY="dtoverlay=vc4-kms-v3d-pi5"
fi
cat >> "${BUILD_DIR}/yunsh-config-new.txt" << YUNSHCONF

# === YUNSH OS Settings ===
arm_64bit=1
[pi5]
${KMS_OVERLAY}
display_auto_detect=1
hdmi_drive=2
hdmi_force_hotplug=1
framebuffer_depth=32
disable_overscan=1
[all]
disable_splash=1
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
# Keep detailed startup diagnostics on the serial console and in the journal,
# while reserving the optical display for the YUNSH splash and spatial UI.
CMDLINE=$(printf '%s\n' "${CMDLINE}" | sed -E \
    -e 's/(^| )(quiet|splash|logo\.nologo|consoleblank=[^ ]+|loglevel=[^ ]+|systemd\.show_status=[^ ]+|systemd\.log_target=[^ ]+|systemd\.log_level=[^ ]+|systemd\.default_standard_output=[^ ]+|vt\.global_cursor_default=[^ ]+|cma=[^ ]+|psi=[^ ]+|module_blacklist=[^ ]+)( |$)/ /g' \
    -e 's/(^| )console=tty[0-9]+( |$)/ /g' \
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
# Keep the canonical Pi 5 SD layout. Serial0
# remains the diagnostic console; tty1 stays clean for splash and UI output.
CMDLINE=$(printf '%s\n' "${CMDLINE}" | sed -E 's/  +/ /g; s/^ +//; s/ +$//')
echo "${CMDLINE} console=tty1 quiet logo.nologo consoleblank=0 loglevel=3 vt.global_cursor_default=0 cma=256M psi=1 systemd.show_status=false systemd.log_target=journal systemd.log_level=notice systemd.default_standard_output=journal" > "${BUILD_DIR}/yunsh-cmdline-new.txt"
mdel -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/yunsh-cmdline-new.txt" ::/cmdline.txt
if grep -Eq '(^| )(splash|module_blacklist=)' "${BUILD_DIR}/yunsh-cmdline-new.txt" ||
   ! grep -Eq '(^| )console=tty1( |$)' "${BUILD_DIR}/yunsh-cmdline-new.txt"; then
    echo "ERROR: boot cmdline is missing the quiet local tty1 display channel or still exposes a splash/GPU blacklist" >&2
    exit 1
fi
echo "  ✓ cmdline.txt modified"

# Copy YUNSH boot files
echo ""
echo "→ YUNSH boot files..."
mcopy -i "${BOOT_IMG}" "${YUNSH_DIR}/boot/yunsh-firstboot.sh" ::/yunsh-firstboot.sh
echo "  ✓ yunsh-firstboot.sh"

# Keep an emergency SSH bootstrap marker in every release image.  The base
# Raspberry Pi OS `sshswitch.service` consumes this marker early in boot and
# enables ssh.service before the online first-boot package transaction starts.
# Without it, a failed download/graphics hand-off leaves a live kernel that
# answers ping but cannot be inspected remotely.
: > "${BUILD_DIR}/ssh"
mdel -i "${BOOT_IMG}" ::/ssh 2>/dev/null || true
mcopy -i "${BOOT_IMG}" "${BUILD_DIR}/ssh" ::/ssh
echo "  ✓ early SSH recovery marker"
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
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -Eq '^dtoverlay=vc4-kms-v3d(-pi5)?([,[:space:]]|$)'
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^disable_fw_kms_setup=1$'
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^hdmi_drive=2'
mtype -i "${BOOT_IMG}" ::/CONFIG.TXT 2>/dev/null | grep -q '^dtparam=i2c_arm=on'
mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'psi=1'
mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'root=/dev/mmcblk0p2'
if ! mtype -i "${BOOT_IMG}" ::/ssh >/dev/null 2>&1; then
    echo "  ✗ Early SSH recovery marker is missing"
    exit 1
fi
if mtype -i "${BOOT_IMG}" ::/CMDLINE.TXT 2>/dev/null | grep -q 'module_blacklist=vc4,v3d'; then
    echo "  ✗ Pi 5 VC4/V3D is blacklisted; primary Wayland cannot start"
    exit 1
fi
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
echo "mkdir /etc/waydroid-extra" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/waydroid-extra/images" >> "${DEBUGFS_SCRIPT}"

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
add_file "${YUNSH_DIR}/system/yunsh-visiond" "/usr/bin/yunsh-visiond"
add_file "${YUNSH_DIR}/system/yunsh-media-setup" "/usr/bin/yunsh-media-setup"
add_file "${YUNSH_DIR}/system/yunsh-grow-root" "/usr/bin/yunsh-grow-root"
add_file "${YUNSH_DIR}/system/yunsh-time-sync" "/usr/bin/yunsh-time-sync"
add_file "${YUNSH_DIR}/system/yunsh-openxr" "/usr/bin/yunsh-openxr"
add_file "${YUNSH_DIR}/system/yunsh-openxr-run" "/usr/bin/yunsh-openxr-run"
add_file "${YUNSH_DIR}/system/yunsh-factory-reset" "/usr/bin/yunsh-factory-reset"
add_file "${YUNSH_DIR}/system/yunsh-install-progress.sh" "/usr/bin/yunsh-install-progress.sh"
add_file "${YUNSH_DIR}/system/yunsh-inputd" "/usr/bin/yunsh-inputd"
add_file "${YUNSH_DIR}/system/yunsh-keyinject" "/usr/bin/yunsh-keyinject"
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
add_file "${YUNSH_DIR}/yunsh-openxr.conf" "/etc/yunsh/openxr.conf"
add_file "${YUNSH_DIR}/yunsh-android.conf" "/etc/yunsh/android.conf"

# Optional offline Android payload. The images are intentionally kept outside
# Git and are injected only when the builder has a complete matching arm64
# pair. This removes the multi-hour first-boot download while keeping builds
# reproducible and preventing a partial payload from being called ready.
ANDROID_PRELOAD_DIR="${YUNSH_ANDROID_PRELOAD_DIR:-${BUILD_DIR}/android-runtime/images}"
if [ -s "${ANDROID_PRELOAD_DIR}/system.img" ] &&
   [ -s "${ANDROID_PRELOAD_DIR}/vendor.img" ]; then
    add_file "${ANDROID_PRELOAD_DIR}/system.img" "/etc/waydroid-extra/images/system.img"
    add_file "${ANDROID_PRELOAD_DIR}/vendor.img" "/etc/waydroid-extra/images/vendor.img"
    echo "  ✓ Preloaded arm64 Waydroid system/vendor images"
else
    echo "  ⚠ No complete arm64 Waydroid preload found"
    if [ "${YUNSH_REQUIRE_ANDROID_PRELOAD:-1}" = "1" ]; then
        echo "ERROR: release image requires a complete arm64 Waydroid system.img/vendor.img pair"
        echo "Run scripts/prepare-waydroid-arm64-images.sh first, or set YUNSH_REQUIRE_ANDROID_PRELOAD=0 for a non-Android development image."
        exit 1
    fi
fi

# Android application stores
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
FDROID_FILE="${BUILD_DIR}/apps/fdroid.apk"
if [ -f "$APK_FILE" ] && [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null)" -gt 1000000 ]; then
    add_file "$APK_FILE" "/usr/share/yunsh/apps/appstore.apk"
    echo "  Tencent Appstore APK injected"
fi
if [ "${YUNSH_INCLUDE_FDROID_FALLBACK:-0}" = "1" ] && [ -f "$FDROID_FILE" ]; then
    add_file "$FDROID_FILE" "/usr/share/yunsh/apps/fdroid.apk"
    echo "  Optional F-Droid fallback injected"
fi

if [ -f "$APK_FILE" ] && [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null || echo 0)" -ge 1000000 ]; then
    echo "  Optional Tencent Appstore APK injected"
elif [ "${YUNSH_INCLUDE_FDROID_FALLBACK:-0}" != "1" ]; then
    echo "ERROR: no valid Android app-store APK is available for the full 4.0 image"
    exit 1
else
    echo "  F-Droid is the configured Android app store"
fi

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
auto_update=true
auto_reboot=true
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
# The shell owns the framebuffer directly. Keep diagnostics in the journal;
# inheriting tty1 makes raw QML/code text flash over activation transitions.
StandardInput=null
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
SVC
add_file "${BUILD_DIR}/yunsh-os.service" "/etc/systemd/system/yunsh-os.service"

# First-boot installer: preserve progress in the journal and on serial0 without
# painting installation logs over the optical display.
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
ExecStartPre=/usr/bin/install -d -m 0755 /var/lib/yunsh/space-inbox /var/lib/yunsh/media /var/lib/yunsh/orbit/voice /run/yunsh
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
ExecStartPre=/usr/bin/install -d -m 0755 /var/lib/yunsh/space-inbox /run/yunsh
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

cat > "${BUILD_DIR}/yunsh-time-sync.service" << 'TIMESVC'
[Unit]
Description=YUNSH OS Boot Time Synchronization
After=NetworkManager.service
ConditionPathExists=/etc/yunsh/.packages_installed

[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-time-sync

[Install]
WantedBy=multi-user.target
TIMESVC
add_file "${BUILD_DIR}/yunsh-time-sync.service" "/etc/systemd/system/yunsh-time-sync.service"

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
After=bluetooth.service yunsh-bluetooth.service yunsh-update.service
Wants=bluetooth.service yunsh-bluetooth.service
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

# USB camera bridge for on-demand AI + XR observation. It is deliberately
# independent from the desktop: missing cameras or ffmpeg must never block UI.
cat > "${BUILD_DIR}/yunsh-vision.service" << 'VISIONSVC'
[Unit]
Description=YUNSH USB Vision Camera Bridge
After=local-fs.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-visiond
Restart=always
RestartSec=5
User=root
UMask=0077
[Install]
WantedBy=multi-user.target
VISIONSVC
add_file "${BUILD_DIR}/yunsh-vision.service" "/etc/systemd/system/yunsh-vision.service"

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

# Install the embedded Android stores after the runtime is ready. This is an
# independent background job: a slow Waydroid session or a bad APK must never
# delay the Linux desktop, activation, or yunsh-os.service.
cat > "${BUILD_DIR}/yunsh-android-store.service" << 'ANDROIDSTORESVC'
[Unit]
Description=YUNSH OS Preinstall Android App Stores
After=yunsh-os.service yunsh-android-setup.service
Wants=yunsh-android-setup.service
ConditionPathExists=/etc/yunsh/.packages_installed
ConditionPathExists=/usr/share/yunsh/apps/appstore.apk
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-android install-store
TimeoutStartSec=900
Restart=on-failure
RestartSec=120
Nice=10
[Install]
WantedBy=multi-user.target
ANDROIDSTORESVC
add_file "${BUILD_DIR}/yunsh-android-store.service" "/etc/systemd/system/yunsh-android-store.service"

# Splash service
cat > "${BUILD_DIR}/yunsh-splash.service" << 'SSVC'
[Unit]
Description=YUNSH OS Boot Splash
After=local-fs.target
Before=yunsh-firstboot.service yunsh-os.service
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
SSVC
add_file "${BUILD_DIR}/yunsh-splash.service" "/etc/systemd/system/yunsh-splash.service"

# Keep an independent post-reboot recovery channel.  The firstboot validator
# refuses to mark setup complete unless SSH and the desktop prerequisites are
# usable; this guard handles the remaining case where a compositor crash
# occurs only after the machine has rebooted.
add_file "${YUNSH_DIR}/system/yunsh-boot-health" "/usr/bin/yunsh-boot-health"
cat > "${BUILD_DIR}/yunsh-boot-health.service" << 'HEALTHSVC'
[Unit]
Description=YUNSH OS Post-Reboot Health Guard
After=local-fs.target network.target
Wants=network.target
ConditionPathExists=/etc/yunsh/.packages_installed
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-boot-health
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
HEALTHSVC
add_file "${BUILD_DIR}/yunsh-boot-health.service" "/etc/systemd/system/yunsh-boot-health.service"

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

add_file "${YUNSH_DIR}/yunsh-openxr.service" "/etc/systemd/system/yunsh-openxr.service"

# Enable services
for service in yunsh-os yunsh-firstboot yunsh-grow-root yunsh-local-api yunsh-spaced yunsh-screen-relay yunsh-network yunsh-bluetooth \
               yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-appd yunsh-android-setup yunsh-android-store yunsh-terminal yunsh-headtracking \
               yunsh-powerd yunsh-splash yunsh-boot-health yunsh-media-setup yunsh-time-sync yunsh-openxr yunsh-vision orbit orbit-voice-setup; do
    echo "rm /etc/systemd/system/multi-user.target.wants/${service}.service" >> "${DEBUGFS_SCRIPT}"
    echo "symlink /etc/systemd/system/multi-user.target.wants/${service}.service ../${service}.service" >> "${DEBUGFS_SCRIPT}"
done
# Network: disable dhcpcd, enable NetworkManager + fstrim
echo "rm /etc/systemd/system/multi-user.target.wants/dhcpcd.service" >> "${DEBUGFS_SCRIPT}"
# SSH is a diagnostic/recovery channel as well as a normal administration
# service.  Enable it in the clean image so it remains available even when
# firstboot stops before the package marker or the graphical shell is ready.
echo "rm /etc/systemd/system/multi-user.target.wants/ssh.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/multi-user.target.wants/ssh.service /lib/systemd/system/ssh.service" >> "${DEBUGFS_SCRIPT}"
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

# Keep tty1 free for the YUNSH splash and UI. The first-boot service owns tty1 while installing,
# but normal boots must not expose kernel/systemd/getty text over the optical display.
echo "rm /etc/systemd/system/getty.target.wants/getty@tty1.service" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/getty@tty1.service" >> "${DEBUGFS_SCRIPT}"
echo "symlink /etc/systemd/system/getty@tty1.service /dev/null" >> "${DEBUGFS_SCRIPT}"
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
           yunsh-boot-health yunsh-appd yunsh-terminal yunsh-disk-helper yunsh-headtracking yunsh-headtracking-sim \
           yunsh-bno085-reader yunsh-activation-helper yunsh-keyinject yunsh-android yunsh-recordingd yunsh-visiond yunsh-media-setup yunsh-grow-root yunsh-time-sync yunsh-openxr yunsh-openxr-run orbitd orbit-voice-setup; do
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
/usr/bin/yunsh-boot-health
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
/usr/bin/yunsh-visiond
/usr/bin/yunsh-media-setup
/usr/bin/yunsh-time-sync
/usr/bin/yunsh-openxr
/usr/bin/yunsh-openxr-run
/usr/share/yunsh/ui/main.qml
/usr/share/yunsh/ui/HomeScreen.qml
/usr/share/yunsh/ui/OrbitPanel.qml
/usr/share/yunsh/ui/SystemMenuBar.qml
/usr/share/yunsh/icons/orbit.png
/usr/share/yunsh/logo/logo-256.png
/etc/yunsh/version.conf
/etc/yunsh/android.conf
/etc/yunsh/openxr.conf
/etc/systemd/system/yunsh-os.service
/etc/systemd/system/yunsh-firstboot.service
/etc/systemd/system/yunsh-boot-health.service
/etc/systemd/system/yunsh-grow-root.service
/etc/systemd/system/yunsh-android-setup.service
/etc/systemd/system/yunsh-android-store.service
/etc/systemd/system/orbit.service
/etc/systemd/system/orbit-voice-setup.service
/etc/systemd/system/yunsh-vision.service
/etc/systemd/system/yunsh-media-setup.service
/etc/systemd/system/yunsh-time-sync.service
/etc/systemd/system/yunsh-openxr.service
/etc/systemd/system/rpi-resize.service
/etc/systemd/system/rpi-resize-swap-file.service
/etc/systemd/system/userconfig.service
/etc/systemd/system/systemd-networkd-wait-online.service
/etc/systemd/system/multi-user.target.wants/yunsh-os.service
/etc/systemd/system/multi-user.target.wants/yunsh-firstboot.service
/etc/systemd/system/multi-user.target.wants/yunsh-boot-health.service
/etc/systemd/system/multi-user.target.wants/yunsh-grow-root.service
/etc/systemd/system/multi-user.target.wants/yunsh-android-setup.service
/etc/systemd/system/multi-user.target.wants/yunsh-android-store.service
/etc/systemd/system/multi-user.target.wants/orbit.service
/etc/systemd/system/multi-user.target.wants/orbit-voice-setup.service
/etc/systemd/system/multi-user.target.wants/yunsh-vision.service
/etc/systemd/system/multi-user.target.wants/yunsh-media-setup.service
/etc/systemd/system/multi-user.target.wants/yunsh-time-sync.service
/etc/systemd/system/multi-user.target.wants/yunsh-openxr.service
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
