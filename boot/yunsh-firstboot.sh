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

touch /etc/yunsh/.firstboot_partial
sync

echo ""
echo "  +------------------------------------------+"
echo "  |  YUNSH OS - First Setup                  |"
echo "  +------------------------------------------+"

source /usr/bin/yunsh-install-progress.sh 2>/dev/null || true

TOTAL=21; CUR=0
pct() { CUR=$((CUR+1)); local P=$((CUR*100/TOTAL)); [ "$P" -gt "$1" ] && P=$1
    if type draw_frame &>/dev/null 2>&1; then draw_frame "$P" "$2" "$CUR" "$TOTAL"
    else echo "  [$P%] $2"; fi
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
    apt-get -f install -yqq --no-install-recommends >>/var/log/yunsh-apt.log 2>&1 || true
}

install_apt() {
    local step="$1" name="$2"; shift 2
    pct "$step" "Installing: $name"
    local attempt=1
    local installed=1
    while [ "$attempt" -le 3 ]; do
        if apt-get install -yqq --no-install-recommends "$@" >>/var/log/yunsh-apt.log 2>&1; then
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
install_apt 8 "Qt6 framework" qt6-base-dev qt6-declarative-dev libqt6svg6 qt6-svg-plugins libqt6opengl6 qt6-base-dev-tools qt6-qmltooling-plugins qml-qt6 qmlscene-qt6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtquick-virtualkeyboard qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtquick-templates
install_apt 14 "Python environment" python3-cryptography python3-pip python3-smbus2
install_apt 20 "WebEngine" qt6-webengine-dev libqt6webenginequick6 qml6-module-qtwebengine
# Keep LXC/Waydroid out of the boot-critical transaction.  Its postinst can
# require kernel cgroup/namespaces that are unavailable in emulators and it
# is already prepared asynchronously by yunsh-android-setup.service.
install_apt 24 "Android display runtime" python3-dbus python3-gi weston libwayland-client0 qml6-module-qtwayland-compositor qt6-wayland
install_apt 32 "Network & BT" network-manager wpasupplicant bluez
install_apt 38 "System tools" openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil psmisc util-linux
install_apt 44 "Chinese fonts" fonts-noto-cjk
# Audio packages are optional for the first desktop frame and can trigger
# debconf contention on a fresh image. Prepare them asynchronously after
# firstboot, alongside the media runtime.
echo "[TRACE] before audio scheduling line=${LINENO}"
pct 50 "Scheduling audio runtime..."
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
CORE_PACKAGES="qml-qt6 qt6-svg-plugins libqt6opengl6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-virtualkeyboard qml6-module-qtquick-templates qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtwebengine qt6-wayland weston network-manager wpasupplicant bluez openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil python3-cryptography python3-smbus2 python3-dbus python3-gi libegl1 libgl1-mesa-dri mesa-vulkan-drivers psmisc util-linux"
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

pct 100 "Setup complete! Rebooting..."
rm -f /etc/yunsh/.firstboot_partial 2>/dev/null || true
touch /etc/yunsh/.packages_installed
rm -f /usr/bin/yunsh-firstboot.sh
sync
sleep 2
reboot
