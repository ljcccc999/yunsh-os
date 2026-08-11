#!/bin/bash
# YUNSH OS - First Boot Setup
# Installs system packages, configures services
# UI files pre-injected into image

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Keep a persistent log as well as the HDMI console.  On a fresh image the
# desktop packages are deliberately installed online; a missing network must
# be diagnosable on-device rather than looking like a blank desktop.
mkdir -p /var/log
exec > >(tee -a /var/log/yunsh-firstboot.log /dev/tty1 /dev/console) 2>&1
trap 'rc=$?; echo "[TRACE] firstboot exit rc=${rc} line=${LINENO}" | tee -a /var/log/yunsh-firstboot.log' EXIT
trap 'echo "[TRACE] firstboot signal TERM line=${LINENO}" | tee -a /var/log/yunsh-firstboot.log; exit 143' TERM
trap 'echo "[TRACE] firstboot signal INT line=${LINENO}" | tee -a /var/log/yunsh-firstboot.log; exit 130' INT
# Firstboot writes progress to tty1 but never reads from a terminal. Do not let
# a getty/console handoff send it SIGHUP and leave the image half-installed.
trap '' HUP

# The image base may move between Debian releases. Never mix a hard-coded
# distribution suite into APT/network checks.
OS_CODENAME="$(
    . /etc/os-release 2>/dev/null || . /usr/lib/os-release 2>/dev/null || true
    printf '%s' "${VERSION_CODENAME:-${DEBIAN_CODENAME:-stable}}"
)"

# Raspberry Pi OS soft-blocks the onboard radio until a regulatory domain is
# selected. YUNSH OS currently ships for Tim's China deployment; keep the
# value overrideable for future regional images instead of leaving phy0 in
# country 00/DFS-UNSET where correct SSIDs and passwords can never connect.
WIFI_COUNTRY="${YUNSH_WIFI_COUNTRY:-CN}"
if [[ "$WIFI_COUNTRY" =~ ^[A-Z]{2}$ ]]; then
    mkdir -p /etc/yunsh
    printf 'COUNTRY=%s\n' "$WIFI_COUNTRY" > /etc/yunsh/wifi-country.conf
    raspi-config nonint do_wifi_country "$WIFI_COUNTRY" >/dev/null 2>&1 || true
    iw reg set "$WIFI_COUNTRY" >/dev/null 2>&1 || true
    rfkill unblock wifi >/dev/null 2>&1 || true
fi

touch /etc/yunsh/.firstboot_partial
sync

echo ""
echo "  +------------------------------------------+"
echo "  |  YUNSH OS - First Setup                  |"
echo "  +------------------------------------------+"

source /usr/bin/yunsh-install-progress.sh 2>/dev/null || true

TOTAL=22; CUR=0; CURRENT_PROGRESS=0; CURRENT_STATUS="Preparing first setup"
FIRSTBOOT_APT_FAILED=0
pct() { CUR=$((CUR+1)); local P=$((CUR*100/TOTAL)); [ "$P" -gt "$1" ] && P=$1
    CURRENT_PROGRESS="$P"; CURRENT_STATUS="$2"
    if type draw_frame &>/dev/null 2>&1; then draw_frame "$P" "$2" "$CUR" "$TOTAL"
    else echo "  [$P%] $2"; fi
}

progress_detail() {
    local status="$1" detail="${2:-}"
    CURRENT_STATUS="$status"
    if type draw_frame &>/dev/null 2>&1; then
        draw_frame "$CURRENT_PROGRESS" "$status" "$CUR" "$TOTAL" "$detail"
    else
        echo "  [$CURRENT_PROGRESS%] $status${detail:+ — $detail}"
    fi
}

# The Linux service account exists before any package transaction or desktop
# startup. Activation later creates a separate YUNSH-local profile and never
# renames or removes this account.
if ! id -u yunsh >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,adm,dialout yunsh 2>/dev/null || true
fi
if ! id -u yunsh >/dev/null 2>&1 || ! echo "yunsh:yunsh123" | chpasswd 2>/dev/null; then
    echo "  [ERROR] Unable to create the Linux service account." >&2
    exit 1
fi

# Raspberry Pi OS' stock user wizard races this installer on a fresh image.
# Besides holding graphical.target, it runs dpkg-reconfigure interactively and
# locks debconf while Qt is being installed.  The builder masks it, and this
# runtime guard repairs images made by an older builder or interrupted OTA.
unit_is_masked() {
    local unit="$1"
    local unit_path="/etc/systemd/system/${unit}"
    [ -L "$unit_path" ] && [ "$(readlink "$unit_path" 2>/dev/null || true)" = "/dev/null" ]
}
if ! unit_is_masked userconfig.service; then
    systemctl stop userconfig.service 2>/dev/null || true
    systemctl disable userconfig.service 2>/dev/null || true
    systemctl mask userconfig.service 2>/dev/null || true
fi
# NetworkManager owns networking in YUNSH OS.  Do not wait two minutes for the
# deliberately unused systemd-networkd daemon on every boot.
if ! unit_is_masked systemd-networkd-wait-online.service; then
    systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
    systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
fi

# ───── Wait for network (up to about 120s) ──
echo -n "  [+] Waiting for network"
WAIT=0
TIMEOUT=24
network_ready() {
    curl -fsI --connect-timeout 2 --max-time 4 \
        "https://deb.debian.org/debian/dists/${OS_CODENAME}/InRelease" &>/dev/null ||
    curl -fsI --connect-timeout 2 --max-time 4 \
        https://deb.debian.org/debian/README &>/dev/null ||
    curl -fsI --connect-timeout 2 --max-time 4 \
        "https://mirrors.tuna.tsinghua.edu.cn/debian/dists/${OS_CODENAME}/InRelease" &>/dev/null
}

APT_OPTIONS=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=15
    -o Acquire::https::Timeout=15
    -o Acquire::ftp::Timeout=15
    -o DPkg::Lock::Timeout=60
)

wait_for_network() {
    local tries="${1:-18}" i=0
    while [ "$i" -lt "$tries" ]; do
        network_ready && return 0
        i=$((i + 1))
        sleep 5
    done
    return 1
}

# Package installation can replace or reconfigure the network stack. Recover
# it inside firstboot instead of waiting forever for APT or requiring a power
# cycle. Starting NetworkManager is safe once its package exists; older base
# images can temporarily fall back to their original network service.
recover_network() {
    network_ready && return 0
    progress_detail "Restoring network connection..." "Automatic recovery"
    apt_services_on 2>/dev/null || true
    if command -v nmcli >/dev/null 2>&1; then
        systemctl enable NetworkManager 2>/dev/null || true
        systemctl restart NetworkManager 2>/dev/null || true
        nmcli networking on 2>/dev/null || true
        nmcli connection reload 2>/dev/null || true
    fi
    systemctl restart systemd-networkd 2>/dev/null || true
    systemctl restart dhcpcd 2>/dev/null || true
    if wait_for_network 18; then
        apt_services_off 2>/dev/null || true
        return 0
    fi
    apt_services_off 2>/dev/null || true
    return 1
}
while ! network_ready; do
    WAIT=$((WAIT+1))
    if [ $WAIT -ge $TIMEOUT ]; then
        echo " [TIMEOUT]"
        echo "  [ERROR] First setup needs an Internet connection."
        echo "  Connect Ethernet, then reboot to retry."
        exit 1
    fi
    [ $((WAIT % 12)) -eq 0 ] && echo -n $'\n  [+] Waiting for network'
    echo -n "."
    sleep 5
done
echo " [OK]"

# Package post-install scripts may try to start LXC/Waydroid, Weston, or
# hardware services while dpkg is still unpacking.  On a first boot that can
# deadlock the transaction (especially in a Pi emulator with no GPU/zram).
# Temporarily block service starts; systemd will start the enabled units after
# the package transaction and the reboot.
APT_POLICY_RC=0
APT_POLICY_BACKUP="/var/lib/yunsh/policy-rc.d.firstboot"
apt_services_off() {
    mkdir -p /var/lib/yunsh
    # Recover from a power loss or forced termination during an earlier
    # firstboot. Never preserve our own temporary policy as the administrator's
    # original policy, or all later service starts remain disabled.
    if [ -e /usr/sbin/policy-rc.d ] &&
       grep -q '^# YUNSH_FIRSTBOOT_POLICY$' /usr/sbin/policy-rc.d 2>/dev/null; then
        if [ -e "$APT_POLICY_BACKUP" ]; then
            mv -f "$APT_POLICY_BACKUP" /usr/sbin/policy-rc.d
        else
            rm -f /usr/sbin/policy-rc.d
        fi
    fi
    rm -f "$APT_POLICY_BACKUP"
    if [ -e /usr/sbin/policy-rc.d ]; then
        cp -a /usr/sbin/policy-rc.d "$APT_POLICY_BACKUP" 2>/dev/null || true
    fi
    cat > /usr/sbin/policy-rc.d <<'POLICY'
#!/bin/sh
# YUNSH_FIRSTBOOT_POLICY
exit 101
POLICY
    chmod 0755 /usr/sbin/policy-rc.d
    APT_POLICY_RC=1
}
apt_services_on() {
    [ "$APT_POLICY_RC" -eq 1 ] || return 0
    if [ -e "$APT_POLICY_BACKUP" ]; then
        mv -f "$APT_POLICY_BACKUP" /usr/sbin/policy-rc.d
    else
        rm -f /usr/sbin/policy-rc.d
    fi
    APT_POLICY_RC=0
}

firstboot_exit() {
    local rc=$?
    apt_services_on || true
    echo "[TRACE] firstboot exit rc=${rc} line=${BASH_LINENO[0]:-${LINENO}}" |
        tee -a /var/log/yunsh-firstboot.log
    trap - EXIT
    exit "$rc"
}
trap firstboot_exit EXIT
apt_services_off

# Debian images may start apt-daily/cloud-init package jobs in parallel with
# firstboot. Stop the scheduled jobs and wait for any transient dpkg/debconf
# lock before taking ownership of the package database.
systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/debconf/config.dat; do
    WAIT_LOCK=0
    while command -v fuser >/dev/null 2>&1 && fuser "$lock" >/dev/null 2>&1; do
        WAIT_LOCK=$((WAIT_LOCK + 1))
        [ "$WAIT_LOCK" -ge 60 ] && break
        sleep 1
    done
done

apt_repair() {
    # A power loss or a terminated firstboot can leave packages unpacked but
    # not configured.  Repair that state before retrying the next package
    # group; otherwise every later apt invocation fails immediately and the
    # desktop marker is never written.
    dpkg --configure -a >>/var/log/yunsh-apt.log 2>&1 || true
    apt-get "${APT_OPTIONS[@]}" -f install -yqq --no-install-recommends >>/var/log/yunsh-apt.log 2>&1 || true
}

apt_download_manifest() {
    local manifest="$1"; shift
    : > "$manifest"
    apt-get "${APT_OPTIONS[@]}" --print-uris -y --no-install-recommends install "$@" \
        2>>/var/log/yunsh-apt.log |
        awk '$1 ~ /^\047/ && $3 ~ /^[0-9]+$/ { print $2 "\t" $3 }' > "$manifest"
}

downloaded_bytes() {
    local manifest="$1" filename expected path actual total=0
    while IFS=$'\t' read -r filename expected; do
        [ -n "$filename" ] || continue
        path="/var/cache/apt/archives/$filename"
        [ -f "$path" ] || path="/var/cache/apt/archives/partial/$filename"
        if [ -f "$path" ]; then
            actual="$(stat -c%s "$path" 2>/dev/null || echo 0)"
            [ "$actual" -gt "$expected" ] 2>/dev/null && actual="$expected"
            total=$((total + actual))
        fi
    done < "$manifest"
    printf '%s' "$total"
}

format_mb() {
    awk -v bytes="${1:-0}" 'BEGIN { printf "%.1f", bytes / 1048576 }'
}

download_apt_group() {
    local name="$1"; shift
    local manifest="/run/yunsh-apt-download-${$}.tsv"
    local total downloaded pid rc total_mb downloaded_mb
    apt_download_manifest "$manifest" "$@"
    total="$(awk -F '\t' '{ total += $2 } END { printf "%.0f", total }' "$manifest")"
    [ -n "$total" ] || total=0
    if [ "$total" -le 0 ]; then
        progress_detail "Download complete: $name" "Already cached or installed"
        rm -f "$manifest"
        return 0
    fi

    total_mb="$(format_mb "$total")"
    apt-get "${APT_OPTIONS[@]}" --download-only -y --no-install-recommends install "$@" \
        >>/var/log/yunsh-apt.log 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        downloaded="$(downloaded_bytes "$manifest")"
        downloaded_mb="$(format_mb "$downloaded")"
        progress_detail "Downloading: $name" "${downloaded_mb} MB / ${total_mb} MB"
        sleep 2
    done
    wait "$pid"; rc=$?
    downloaded="$(downloaded_bytes "$manifest")"
    progress_detail "Downloading: $name" "$(format_mb "$downloaded") MB / ${total_mb} MB"
    rm -f "$manifest"
    return "$rc"
}

install_apt() {
    local step="$1" name="$2"; shift 2
    pct "$step" "Installing: $name"
    local attempt=1
    local installed=1
    while [ "$attempt" -le 3 ]; do
        if ! network_ready && ! recover_network; then
            echo "  [WARN] Network unavailable before package group: $name" | tee -a /var/log/yunsh-apt.log
        fi
        if download_apt_group "$name" "$@"; then
            progress_detail "Unpacking and configuring: $name" "Downloaded packages are being installed"
        fi
        if apt-get "${APT_OPTIONS[@]}" --no-download install -yqq --no-install-recommends "$@" >>/var/log/yunsh-apt.log 2>&1; then
            installed=0
            break
        fi
        echo "  [WARN] Package group failed (attempt $attempt/3): $name" | tee -a /var/log/yunsh-apt.log
        apt_repair
        sleep $((attempt * 5))
        attempt=$((attempt + 1))
    done
    if [ "$installed" -ne 0 ]; then
        echo "  [ERROR] Package group did not complete: $name" | tee -a /var/log/yunsh-apt.log
        FIRSTBOOT_APT_FAILED=1
    fi
    apt-get clean -qq >>/var/log/yunsh-apt.log 2>&1 || true
}

# Do not call an installation successful merely because dpkg has unpacked the
# requested packages.  The previous flow wrote .packages_installed and
# rebooted even when sshd or the desktop launch prerequisites were not usable;
# that produced a perfectly alive kernel with a black screen and no SSH port.
# Keep the marker absent on failure so systemd retries firstboot and the
# on-device progress/log remains available for diagnosis.
validate_pre_reboot() {
    local qml_runner=""
    echo ""
    echo "  [+] Validating reboot handoff..."

    if [ "$FIRSTBOOT_APT_FAILED" -ne 0 ]; then
        echo "  [ERROR] One or more package groups did not complete."
        return 1
    fi

    if [ ! -x /usr/bin/yunsh-ui-launcher ]; then
        echo "  [ERROR] Desktop launcher is missing."
        return 1
    fi
    command -v weston >/dev/null 2>&1 || {
        echo "  [ERROR] Weston is not installed."
        return 1
    }
    if [ -x /usr/lib/qt6/bin/qml ]; then
        qml_runner=/usr/lib/qt6/bin/qml
    elif [ -x /usr/lib/qt6/bin/qmlscene ]; then
        qml_runner=/usr/lib/qt6/bin/qmlscene
    else
        qml_runner="$(command -v qml6 || command -v qml || true)"
    fi
    if [ -z "$qml_runner" ]; then
        echo "  [ERROR] Qt QML runtime is not installed."
        return 1
    fi

    systemctl daemon-reload || return 1
    if ! systemctl enable ssh.service >/dev/null 2>&1; then
        echo "  [ERROR] SSH service could not be enabled."
        return 1
    fi
    # Start and verify SSH before writing the completion marker.  This is a
    # local check; it does not depend on a DHCP lease or the user's current
    # Wi-Fi address.
    if ! systemctl start ssh.service >/dev/null 2>&1; then
        echo "  [ERROR] SSH service could not be started."
        return 1
    fi
    if ! systemctl is-active --quiet ssh.service; then
        echo "  [ERROR] SSH service is not active after start."
        return 1
    fi
    if ! systemctl enable yunsh-os.service >/dev/null 2>&1; then
        echo "  [ERROR] Desktop service could not be enabled."
        return 1
    fi
    if ! systemctl is-enabled --quiet yunsh-os.service; then
        echo "  [ERROR] Desktop service is not enabled for the next boot."
        return 1
    fi

    echo "  [OK] SSH service enabled and active"
    echo "  [OK] Desktop launcher, Weston, and Qt QML runtime present"
    echo "  [OK] Desktop service enabled for post-reboot startup"
    return 0
}

# ───── Firewall & SSH Security Setup ────────────
setup_firewall() {
    local FIREWALL_DONE="/etc/yunsh/.firewall_configured"
    local SSH_DONE="/etc/yunsh/.ssh_hardened"
    local BOOT_MNT="/boot/firmware"

    # ── Firewall ──
    if [ ! -f "$FIREWALL_DONE" ]; then
        echo "  [+] Installing firewall rules..."
        # Prefer the rootfs copy; use the boot copy as a recovery source.
        if [ -f "$BOOT_MNT/yunsh-iptables.sh" ]; then
            cp "$BOOT_MNT/yunsh-iptables.sh" /usr/bin/yunsh-iptables.sh
            chmod +x /usr/bin/yunsh-iptables.sh
        fi

        if [ -x /usr/bin/yunsh-iptables.sh ]; then

            cat > /etc/systemd/system/yunsh-firewall.service << 'UNIT'
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
UNIT

            systemctl daemon-reload
            if systemctl enable yunsh-firewall.service; then
                if systemctl start yunsh-firewall.service; then
                    touch "$FIREWALL_DONE"
                    echo "  [OK] Firewall configured and enabled"
                else
                    echo "  [WARN] Firewall will retry at the next boot"
                fi
            else
                echo "  [WARN] Firewall service could not be enabled"
            fi
        else
            echo "  [WARN] yunsh-iptables.sh not found, firewall not configured"
        fi
    else
        echo "  [SKIP] Firewall already configured"
    fi

    # ── SSH Hardening ──
    if [ ! -f "$SSH_DONE" ]; then
        echo "  [+] Hardening SSH configuration..."
        mkdir -p /etc/ssh/sshd_config.d
        cat > /etc/ssh/sshd_config.d/yunsh.conf << 'SSH'
# YUNSH OS - SSH Server Hardening
Port 22
Protocol 2
MaxAuthTries 3
ClientAliveInterval 120
ClientAliveCountMax 3
PermitRootLogin prohibit-password
PasswordAuthentication yes
X11Forwarding no
SSH
        chmod 644 /etc/ssh/sshd_config.d/yunsh.conf

        # Remove old-style permit-root section if present in sshd_config
        sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config 2>/dev/null || true

        systemctl restart sshd || systemctl restart ssh 2>/dev/null || true
        echo "  [OK] SSH hardening applied and sshd restarted"
        touch "$SSH_DONE"
    else
        echo "  [SKIP] SSH already hardened"
    fi
}

# Wait for NTP (max 30s)
for i in $(seq 1 30); do
    timedatectl show -p NTPSynchronized 2>/dev/null | grep -q "yes" && break
    sleep 1
done

pct 3 "Updating package lists..."
apt-get update -qq 2>/dev/null || { sleep 10; apt-get update -qq 2>/dev/null || true; }

# Install packages
# Keep the Pi 5 kernel, firmware and utility stack current before the desktop
# starts.  A stale firmware/clock provider can leave vc4-drm unbound, which
# makes Weston report "no drm device found" even when the HDMI overlay exists.
install_apt 6 "Raspberry Pi kernel and firmware" linux-image-rpi-2712 raspi-firmware raspi-utils-core
install_apt 8 "Qt6 framework" qt6-base-dev qt6-declarative-dev libqt6svg6 qt6-svg-plugins libqt6opengl6 qt6-base-dev-tools qt6-qmltooling-plugins qml-qt6 qmlscene-qt6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtquick-virtualkeyboard qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtquick-templates
install_apt 14 "Python environment" python3-cryptography python3-pip python3-smbus2
install_apt 20 "WebEngine" qt6-webengine-dev libqt6webenginequick6 qml6-module-qtwebengine
# Keep LXC/Waydroid out of the boot-critical transaction.  Its postinst can
# require kernel cgroup/namespaces that are unavailable in emulators and it
# is already prepared asynchronously by yunsh-android-setup.service.
install_apt 24 "Android display runtime" python3-dbus python3-gi weston libwayland-client0 qml6-module-qtwayland-compositor qt6-wayland
install_apt 32 "Network & BT" network-manager wpasupplicant bluez
# NetworkManager is needed by the final OS and its package installation can
# alter the currently active link. Start it immediately, verify real Internet
# access, and let systemd retry firstboot automatically if the handoff fails.
apt_services_on
progress_detail "Activating NetworkManager..." "Keeping first-boot downloads online"
systemctl enable NetworkManager 2>/dev/null || true
systemctl restart NetworkManager 2>/dev/null || true
nmcli networking on 2>/dev/null || true
nmcli connection reload 2>/dev/null || true
if ! wait_for_network 18 && ! recover_network; then
    echo "  [ERROR] NetworkManager handoff failed; firstboot will retry automatically." | tee -a /var/log/yunsh-apt.log
    exit 1
fi
apt_services_off
install_apt 38 "System tools" openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil psmisc util-linux
install_apt 44 "Chinese input and emoji" fonts-noto-cjk fonts-noto-color-emoji fcitx5 fcitx5-chinese-addons fcitx5-frontend-qt6 python3-pam
# Audio packages are optional for the first desktop frame and can trigger
# debconf contention on a fresh image. Prepare them asynchronously after
# firstboot, alongside the media runtime.
echo "[TRACE] before audio scheduling line=${LINENO}"
install_apt 50 "Bluetooth audio speakers" pulseaudio pulseaudio-module-bluetooth
echo "[TRACE] after audio scheduling line=${LINENO}"
# Screen capture, recording, and OCR are optional and can contend with
# cloud-init's debconf database on a fresh image. Prepare all of them
# asynchronously with yunsh-media-setup.service after the desktop marker.
pct 53 "Scheduling screen capture and recording..."
# wf-recorder is also installed asynchronously by yunsh-media-setup.service.
# Raspberry Pi 5 uses the BCM2712 VideoCore VII through the DRM/KMS + V3D
# stack. Keep both EGL/OpenGL (Qt Quick/Weston) and Vulkan (Waydroid and
# future spatial compositor work) in the first-boot transaction, rather than
# silently falling back to an incomplete software graphics stack.
install_apt 56 "Pi 5 graphics runtime" mesa-utils libgl1-mesa-dri libegl1 mesa-vulkan-drivers

# Waydroid remains a core component, but its repository and Android image are
# external network dependencies. They must never block activation or desktop
# startup. yunsh-android-setup.service prepares it in the background and
# retries safely after this first-boot transaction has completed.
pct 58 "Scheduling Android runtime setup..."
apt_services_on
mkdir -p /var/lib/yunsh
printf '{"state":"pending","progress":0,"message":"Android setup is queued"}\n' \
    > /var/lib/yunsh/android-setup.json

pct 62 "Checking desktop runtime..."

pct 68 "Starting core services..."
systemctl enable NetworkManager bluetooth ssh 2>/dev/null || true
systemctl start NetworkManager bluetooth 2>/dev/null || true
systemctl disable dhcpcd 2>/dev/null || true
systemctl stop dhcpcd 2>/dev/null || true

pct 74 "Configuring YUNSH OS..."
mkdir -p /etc/yunsh

pct 78 "Configuring firewall & SSH..."
setup_firewall

pct 84 "Enabling YUNSH services..."
systemctl enable yunsh-os yunsh-local-api yunsh-network yunsh-bluetooth yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-spaced yunsh-screen-relay \
    yunsh-appd yunsh-android-setup yunsh-terminal yunsh-headtracking yunsh-powerd \
    fstrim.timer 2>/dev/null || true

pct 86 "Creating default user..."
usermod -a -G sudo,adm,dialout yunsh 2>/dev/null || true
ssh-keygen -A 2>/dev/null || true
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1 2>/dev/null || true
if grep -qE '^[[:space:]]*127\.0\.1\.1[[:space:]]+' /etc/hosts 2>/dev/null; then
    sed -i -E 's/^[[:space:]]*127\.0\.1\.1[[:space:]]+.*/127.0.1.1 yunsh-v1/' /etc/hosts
else
    printf '\n127.0.1.1 yunsh-v1\n' >> /etc/hosts
fi

pct 92 "Preparing Android application store..."
# Installation occurs after Weston is available. A verified F-Droid APK is
# embedded by the image builder, so App installation never depends on Tencent's
# frequently changing download URL.
[ -x /usr/bin/yunsh-android ] || {
    echo "  [ERROR] Android application controller is missing."
    exit 1
}

# Package groups have already completed with retries above. Do not run an
# unbounded final apt repair here: a background debconf lock could otherwise
# prevent the desktop marker from ever being written. The exact core package
# status check below is the authoritative gate.

pct 98 "Cleaning up..."
CORE_PACKAGES="linux-image-rpi-2712 raspi-firmware raspi-utils-core qml-qt6 qt6-svg-plugins libqt6opengl6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-virtualkeyboard qml6-module-qtquick-templates qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtwebengine qt6-wayland weston network-manager wpasupplicant bluez openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil python3-cryptography python3-smbus2 python3-dbus python3-gi python3-pam libegl1 libgl1-mesa-dri mesa-vulkan-drivers psmisc util-linux fonts-noto-cjk fonts-noto-color-emoji fcitx5 fcitx5-chinese-addons fcitx5-frontend-qt6 pulseaudio pulseaudio-module-bluetooth"
CORE_MISSING=""
for package in $CORE_PACKAGES; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
        grep -q "install ok installed" || CORE_MISSING="$CORE_MISSING $package"
done
if { [ ! -x /usr/lib/qt6/bin/qml ] && \
      ! command -v qml6 >/dev/null 2>&1 && \
      ! command -v qml >/dev/null 2>&1; } || [ -n "$CORE_MISSING" ]; then
    echo ""
    echo "  [ERROR] Required desktop packages are missing:$CORE_MISSING"
    echo "  DPKG details are in /var/log/yunsh-apt.log; reboot to retry."
    exit 1
fi

if ! validate_pre_reboot; then
    echo "  [ERROR] Reboot handoff validation failed; installation will retry without marking completion."
    exit 1
fi

pct 100 "Setup complete! Rebooting..."
rm -f /etc/yunsh/.firstboot_partial 2>/dev/null || true
touch /etc/yunsh/.packages_installed
rm -f /usr/bin/yunsh-firstboot.sh
sync
sleep 2
reboot
