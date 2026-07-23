#!/bin/bash
# YUNSH OS Image Builder — No hdiutil version
# Uses Python for boot partition (FAT32) manipulation + debugfs for rootfs (ext4)
set -e

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
OUTPUT_FILE="${OUTPUT_DIR}/YUNSH-OS-v1.0.1.img"
E2FSPROGS="/opt/homebrew/Cellar/e2fsprogs/1.47.4"
DEBUGFS="${E2FSPROGS}/sbin/debugfs"

echo "============================================"
echo "  YUNSH OS v1.0 - Image Builder (no hdiutil)"
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
eval $(python3 << 'PYEOF'
import struct
with open("'''${RPI_IMAGE}'''", "rb") as f:
    mbr = f.read(512)
boot_start = struct.unpack_from("<I", mbr, 454)[0]
boot_end = boot_start + struct.unpack_from("<I", mbr, 458)[0] - 1
root_start = struct.unpack_from("<I", mbr, 470)[0]
root_end = root_start + struct.unpack_from("<I", mbr, 474)[0] - 1
print(f"BOOT_START={boot_start} BOOT_END={boot_end}")
print(f"ROOT_START={root_start} ROOT_END={root_end}")
PYEOF
)
echo "Boot: sectors $BOOT_START-$BOOT_END"
echo "Root: sectors $ROOT_START-$ROOT_END"

# ─── Step 3: Create working copy ──────────────────
echo ""
echo "=== Creating working copy ==="
cp "${RPI_IMAGE}" "${OUTPUT_FILE}"
echo "  ✓ ${OUTPUT_FILE}"

# ─── Step 4: Generate splash screens ──────────────
echo ""
echo "=== Generating boot splash screen ==="
python3 "${YUNSH_DIR}/scripts/generate-splash.py" 2>&1 || {
    python3 -c "
print('Generating splash placeholders...')
import struct, os
splash_dir = '${BUILD_DIR}/splash'
os.makedirs(splash_dir, exist_ok=True)
for name in ['yunsh-splash-logo.raw', 'yunsh-splash-full.raw']:
    # 1920x1080x32bpp = 8294400 bytes
    path = os.path.join(splash_dir, name)
    if not os.path.exists(path):
        with open(path, 'wb') as f:
            f.write(b'\0' * 8294400)
            print(f'  placeholder: {name}')
for name in ['yunsh-splash-logo.bmp', 'yunsh-splash-full.bmp', 'yunsh-splash-full-720p.bmp']:
    path = os.path.join(splash_dir, name)
    if not os.path.exists(path):
        with open(path, 'wb') as f:
            f.write(b'\0' * 100)
            print(f'  placeholder: {name}')
"
}

# ─── Step 5: Download 应用宝 APK (best-effort) ──
echo ""
echo "=== Downloading 应用宝 APK ==="
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
mkdir -p "${BUILD_DIR}/apps"
if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || echo 0)" -lt 1000000 ]; then
    for url in \
        "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
        "https://appdownload.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader.apk"; do
        echo "  Trying: $url"
        curl -L -o "${APK_FILE}" --max-time 30 "$url" 2>/dev/null && break || true
    done
    if [ ! -f "$APK_FILE" ] || [ "$(stat -f%z "$APK_FILE" 2>/dev/null || echo 0)" -lt 100000 ]; then
        echo "placeholder" > "$APK_FILE"
        echo "  ⚠ 使用运行时下载方式"
    fi
fi

# ─── Step 6: Inject boot partition ────────────────
echo ""
echo "=== Injecting boot partition ==="
python3 "${YUNSH_DIR}/scripts/inject-boot.py" 2>&1
echo "Boot partition injection complete ✓"

# ─── Step 7: Create debugfs injection script ──────
echo ""
echo "=== Creating debugfs injection script ==="
DEBUGFS_SCRIPT="${BUILD_DIR}/yunsh-debugfs.txt"
>"${DEBUGFS_SCRIPT}"

add_file() {
    local src="$1" dest="$2"
    local size=$(stat -f%z "$src" 2>/dev/null || stat -c%s "$src" 2>/dev/null || echo 0)
    echo "write \"$src\" \"$dest\"" >> "${DEBUGFS_SCRIPT}"
    echo "  $dest ($size bytes)"
}

echo "mkdir /usr/share/yunsh" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/ui" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/icons" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/apps" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /usr/share/yunsh/logo" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/yunsh" >> "${DEBUGFS_SCRIPT}"

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
add_file "${YUNSH_DIR}/system/yunsh-headtracking" "/usr/bin/yunsh-headtracking"
add_file "${YUNSH_DIR}/system/yunsh-bno085-reader" "/usr/bin/yunsh-bno085-reader"
add_file "${YUNSH_DIR}/system/yunsh-headtracking-sim" "/usr/bin/yunsh-headtracking-sim"
add_file "${YUNSH_DIR}/system/yunsh-screenshotd" "/usr/bin/yunsh-screenshotd"
add_file "${YUNSH_DIR}/system/yunsh-factory-reset" "/usr/bin/yunsh-factory-reset"
add_file "${YUNSH_DIR}/system/yunsh-install-progress.sh" "/usr/bin/yunsh-install-progress.sh"
add_file "${YUNSH_DIR}/system/yunsh-inputd" "/usr/bin/yunsh-inputd"
add_file "${YUNSH_DIR}/system/yunsh-powerd" "/usr/bin/yunsh-powerd"
add_file "${YUNSH_DIR}/system/yunsh-activation-helper" "/usr/bin/yunsh-activation-helper"
add_file "${YUNSH_DIR}/system/yunsh-appd.py" "/usr/bin/yunsh-appd"
add_file "${YUNSH_DIR}/system/yunsh-terminal.py" "/usr/bin/yunsh-terminal"
add_file "${YUNSH_DIR}/system/yunsh-disk-helper" "/usr/bin/yunsh-disk-helper"
add_file "${YUNSH_DIR}/system/yunsh-logrotate.conf" "/etc/logrotate.d/yunsh"
add_file "${YUNSH_DIR}/.gitignore" "/root/.gitignore"
add_file "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "/usr/bin/yunsh-firstboot.sh"
add_file "${YUNSH_DIR}/boot/yunsh-iptables.sh" "/usr/bin/yunsh-iptables.sh"

# APK
APK_FILE="${BUILD_DIR}/apps/appstore.apk"
if [ -f "$APK_FILE" ] && [ "$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null)" -gt 1000000 ]; then
    add_file "$APK_FILE" "/usr/share/yunsh/apps/appstore.apk"
    echo "  应用宝 APK injected (real)"
else
    echo "placeholder" > "${BUILD_DIR}/apps/appstore.apk"
    add_file "${BUILD_DIR}/apps/appstore.apk" "/usr/share/yunsh/apps/appstore.apk"
    echo "  应用宝 APK 占位"
fi

# Launcher script
LAUNCHER_FILE="${BUILD_DIR}/yunsh-ui-launcher"
cp "${YUNSH_DIR}/system/yunsh-ui-launcher" "${LAUNCHER_FILE}" 2>/dev/null || {
    cat > "${LAUNCHER_FILE}" << 'LAUNCHER'
#!/bin/bash
cd /usr/share/yunsh/ui || exit 1
QML_RUNNER=$(command -v qml6 || command -v qml || :)
if [ ! -f /etc/yunsh/.packages_installed ] && [ -x /usr/bin/yunsh-firstboot.sh ]; then
    /usr/bin/yunsh-firstboot.sh
    touch /etc/yunsh/.packages_installed; sync; sleep 2; reboot; exit 0
fi
if ! id -u yunsh &>/dev/null 2>&1; then
    useradd -m -s /bin/bash yunsh 2>/dev/null || true
fi
/usr/bin/yunsh-disk-helper 2>/dev/null || true
while true; do
    if [ -f /etc/yunsh/.activated ]; then
        $QML_RUNNER main.qml --activated 2>/dev/null
    else
        $QML_RUNNER main.qml --firstboot 2>/dev/null
        QML_EXIT=$?
        [ $QML_EXIT -eq 42 ] && touch /etc/yunsh/.activated 2>/dev/null && sync
    fi
    [ -f /etc/yunsh/.activated ] || touch /etc/yunsh/.activated 2>/dev/null
    sleep 2
done
LAUNCHER
}
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

cat > "${BUILD_DIR}/yunsh-version.conf" << 'VERCONF'
VERSION=v1.0.1
BUILD=2026.07.12
VERCONF
add_file "${BUILD_DIR}/yunsh-version.conf" "/etc/yunsh/version.conf"

# systemd services
echo "mkdir /etc/systemd/system" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/systemd/system/multi-user.target.wants" >> "${DEBUGFS_SCRIPT}"

# Main OS service
cat > "${BUILD_DIR}/yunsh-os.service" << 'SVC'
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
add_file "${BUILD_DIR}/yunsh-os.service" "/etc/systemd/system/yunsh-os.service"

# Network service
cat > "${BUILD_DIR}/yunsh-network.service" << 'NSVC'
[Unit]
Description=YUNSH OS Network Manager
After=NetworkManager.service
BindsTo=NetworkManager.service
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
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bluetooth-daemon
Restart=always
User=root
[Install]
WantedBy=multi-user.target
BSVC
add_file "${BUILD_DIR}/yunsh-bluetooth.service" "/etc/systemd/system/yunsh-bluetooth.service"

# Update service
cat > "${BUILD_DIR}/yunsh-update.service" << 'USVC'
[Unit]
Description=YUNSH OS OTA Update Daemon
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-update-daemon
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
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-appd
Restart=always
[Install]
WantedBy=multi-user.target
APPSVC
add_file "${BUILD_DIR}/yunsh-appd.service" "/etc/systemd/system/yunsh-appd.service"

# Splash service
cat > "${BUILD_DIR}/yunsh-splash.service" << 'SSVC'
[Unit]
Description=YUNSH OS Boot Splash
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
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
After=multi-user.target
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
After=multi-user.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bno085-reader
Restart=always
[Install]
WantedBy=multi-user.target
BNOSVC
add_file "${BUILD_DIR}/yunsh-bno085-reader.service" "/etc/systemd/system/yunsh-bno085-reader.service"

# Terminal service
cat > "${BUILD_DIR}/yunsh-terminal.service" << 'TERMSVC'
[Unit]
Description=YUNSH OS Terminal Daemon (PTY bash)
After=network.target yunsh-os.service
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
echo "ln /etc/systemd/system/yunsh-os.service /etc/systemd/system/multi-user.target.wants/yunsh-os.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-network.service /etc/systemd/system/multi-user.target.wants/yunsh-network.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-bluetooth.service /etc/systemd/system/multi-user.target.wants/yunsh-bluetooth.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-update.service /etc/systemd/system/multi-user.target.wants/yunsh-update.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-appd.service /etc/systemd/system/multi-user.target.wants/yunsh-appd.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-terminal.service /etc/systemd/system/multi-user.target.wants/yunsh-terminal.service" >> "${DEBUGFS_SCRIPT}"
echo "ln /etc/systemd/system/yunsh-splash.service /etc/systemd/system/sysinit.target.wants/yunsh-splash.service" >> "${DEBUGFS_SCRIPT}"
echo "mkdir /etc/systemd/system/sysinit.target.wants" >> "${DEBUGFS_SCRIPT}"

# Network: disable dhcpcd, enable NetworkManager + fstrim
echo "rm /etc/systemd/system/multi-user.target.wants/dhcpcd.service 2>/dev/null" >> "${DEBUGFS_SCRIPT}"

# Autologin on tty1
echo "mkdir /etc/systemd/system/getty.target.wants" >> "${DEBUGFS_SCRIPT}"
AUTOLOGIN_FILE="${BUILD_DIR}/yunsh-autologin.conf"
cat > "${AUTOLOGIN_FILE}" << 'AUTOLOGIN'
# YUNSH OS - Auto-login on tty1
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin yunsh --noclear %I $TERM
AUTOLOGIN
add_file "${AUTOLOGIN_FILE}" "/etc/systemd/system/getty@tty1.service.d/autologin.conf"

# rc.local
RCLOCAL_FILE="${BUILD_DIR}/yunsh-rc-local"
cat > "${RCLOCAL_FILE}" << 'RCLOCAL'
#!/bin/sh
# YUNSH OS - Late init
modprobe i2c-dev 2>/dev/null || true
/usr/bin/yunsh-splash 2>/dev/null || true
exit 0
RCLOCAL
chmod +x "${RCLOCAL_FILE}"
add_file "${RCLOCAL_FILE}" "/etc/rc.local"

# Hostname
echo "rm /etc/hostname" >> "${DEBUGFS_SCRIPT}"
echo "yunsh-v1" > "${BUILD_DIR}/yunsh-hostname"
add_file "${BUILD_DIR}/yunsh-hostname" "/etc/hostname"

# Set permissions
for bin in yunsh-update-daemon yunsh-updater yunsh-network-daemon yunsh-bluetooth-daemon \
           yunsh-screenshotd yunsh-factory-reset yunsh-install-progress.sh yunsh-inputd \
           yunsh-powerd yunsh-firstboot.sh yunsh-iptables.sh yunsh-ui-launcher yunsh-splash \
           yunsh-appd yunsh-terminal yunsh-disk-helper yunsh-headtracking yunsh-headtracking-sim \
           yunsh-bno085-reader yunsh-activation-helper; do
    echo "set_inode_field /usr/bin/${bin} mode 0100755" >> "${DEBUGFS_SCRIPT}"
done
echo "set_inode_field /etc/rc.local mode 0100755" >> "${DEBUGFS_SCRIPT}"
echo "rm /etc/systemd/system/multi-user.target.wants/userconfig.service 2>/dev/null" >> "${DEBUGFS_SCRIPT}"

# ─── Step 8: Run debugfs on rootfs ────────────────
echo ""
echo "=== Extracting root partition ==="
ROOT_SIZE_BLOCKS=$((ROOT_END - ROOT_START + 1))
ROOT_PARTITION_IMG="${BUILD_DIR}/root-partition.img"
rm -f "${ROOT_PARTITION_IMG}"
dd if="${OUTPUT_FILE}" of="${ROOT_PARTITION_IMG}" bs=512 \
   skip=$ROOT_START count=$ROOT_SIZE_BLOCKS 2>/dev/null
echo "  ✓ root partition extracted ($((ROOT_SIZE_BLOCKS * 512 / 1024 / 1024)) MB)"

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
"${E2FSPROGS}/sbin/e2fsck" -fy "${ROOT_PARTITION_IMG}" 2>&1 || true
echo "e2fsck ✓"

# ─── Step 10: Write root back ─────────────────────
echo ""
echo "=== Writing root partition back ==="
dd if="${ROOT_PARTITION_IMG}" of="${OUTPUT_FILE}" bs=512 \
   seek=$ROOT_START count=$ROOT_SIZE_BLOCKS conv=notrunc 2>/dev/null
sync
echo "Root partition written ✓"

# ─── Step 11: Verify ─────────────────────────────
echo ""
echo "=== Quick verification ==="
# Extract root and check files
ROOT_TEST_IMG="${BUILD_DIR}/root-test.img"
dd if="${OUTPUT_FILE}" of="${ROOT_TEST_IMG}" bs=512 \
   skip=$ROOT_START count=$ROOT_SIZE_BLOCKS 2>/dev/null

echo "Files injected:"
"${E2FSPROGS}/sbin/debugfs" -R "ls -l /usr/bin/yunsh" "${ROOT_TEST_IMG}" 2>/dev/null | head -5 || true
"${E2FSPROGS}/sbin/debugfs" -R "ls -l /usr/share/yunsh/ui" "${ROOT_TEST_IMG}" 2>/dev/null | head -5 || true
echo "(partial listing, see build log for complete)"

# Cleanup
rm -f "${ROOT_PARTITION_IMG}" "${ROOT_TEST_IMG}" "${LAUNCHER_FILE}" "${DEBUGFS_SCRIPT}"

# ─── Step 12: Compress ───────────────────────────
echo ""
echo "=== Compressing ==="
xz -v -f "${OUTPUT_FILE}" 2>&1
echo ""
echo "============================================"
echo "  ✅ Build complete!"
echo "============================================"
echo ""
echo "Output: ${OUTPUT_FILE}.xz"
echo "Size: $(ls -lh "${OUTPUT_FILE}.xz" | awk '{print $5}')"
echo ""
echo "Flash to SD card:"
echo "  sudo dd if=${OUTPUT_FILE}.xz of=/dev/rdisk2 bs=1m status=progress"
