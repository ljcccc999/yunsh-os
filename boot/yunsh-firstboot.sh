#!/bin/bash
# YUNSH OS v1.0.1 - First Boot Setup (v5)
# Installs system packages, configures services
# UI files pre-injected into image

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Redirect ALL output to tty1 so Tim can see progress on HDMI
exec > /dev/tty1 2>&1

touch /etc/yunsh/.firstboot_partial
sync

echo ""
echo "  +------------------------------------------+"
echo "  |  YUNSH OS v1.0.1 - First Time Setup      |"
echo "  +------------------------------------------+"

source /usr/bin/yunsh-install-progress.sh 2>/dev/null || true

TOTAL=14; CUR=0
pct() { CUR=$((CUR+1)); local P=$((CUR*100/TOTAL)); [ "$P" -gt "$1" ] && P=$1
    if type draw_frame &>/dev/null 2>&1; then draw_frame "$P" "$2" "$CUR" "$TOTAL"
    else echo "  [$P%] $2"; fi
}

# ───── Wait for network (up to 120s timeout) ──
echo -n "  [+] Waiting for network"
WAIT=0
TIMEOUT=120   # Max 120 seconds waiting for network
while ! ping -c1 -W2 223.5.5.5 &>/dev/null && \
      ! ping -c1 -W2 114.114.114.114 &>/dev/null && \
      ! curl -s --max-time 3 http://mirrors.tuna.tsinghua.edu.cn/ &>/dev/null && \
      ! curl -s --max-time 3 http://deb.debian.org/ &>/dev/null; do
    WAIT=$((WAIT+1))
    if [ $WAIT -ge $TIMEOUT ]; then
        echo " [TIMEOUT]"
        echo "  ⚠ Network not available after ${TIMEOUT}s, continuing anyway..."
        break
    fi
    [ $((WAIT % 12)) -eq 0 ] && echo -n $'\n  [+] Waiting for network'
    echo -n "."
    sleep 5
done
echo " [OK]"

if [ $WAIT -gt 60 ]; then
    MIRROR="http://mirrors.tuna.tsinghua.edu.cn"
else
    MIRROR="http://deb.debian.org/debian"
fi

# Switch mirrors
for sf in /etc/apt/sources.list.d/*.sources; do
    [ -f "$sf" ] || continue
    sed -i "s|URIs: http://deb.debian.org/debian|URIs: $MIRROR/debian|g" "$sf" 2>/dev/null || true
    sed -i "s|URIs: http://archive.raspberrypi.com/debian|URIs: $MIRROR/raspberrypi|g" "$sf" 2>/dev/null || true
done
grep -q "deb.debian.org" /etc/apt/sources.list 2>/dev/null && {
    sed -i "s|http://deb.debian.org/debian|$MIRROR/debian|g" /etc/apt/sources.list 2>/dev/null || true
    sed -i "s|https://deb.debian.org/debian|$MIRROR/debian|g" /etc/apt/sources.list 2>/dev/null || true
}

install_apt() {
    local step="$1" name="$2"; shift 2
    pct "$step" "Installing: $name"
    apt-get install -yqq --no-install-recommends "$@" 2>/dev/null || {
        sleep 5
        apt-get install -yqq --no-install-recommends "$@" 2>/dev/null || {
            sleep 10
            apt-get install -yqq --no-install-recommends "$@" 2>/dev/null || true
        }
    }
    apt-get clean -qq 2>/dev/null || true
}

# ───── Firewall & SSH Security Setup ────────────
setup_firewall() {
    local FIREWALL_DONE="/etc/yunsh/.firewall_configured"
    local SSH_DONE="/etc/yunsh/.ssh_hardened"
    local BOOT_MNT="/boot/firmware"

    # ── Firewall ──
    if [ ! -f "$FIREWALL_DONE" ]; then
        echo "  [+] Installing firewall rules..."
        # iptables script is copied to boot partition during build
        if [ -f "$BOOT_MNT/yunsh-iptables.sh" ]; then
            cp "$BOOT_MNT/yunsh-iptables.sh" /usr/bin/yunsh-iptables.sh
            chmod +x /usr/bin/yunsh-iptables.sh

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
            systemctl enable yunsh-firewall.service
            systemctl start yunsh-firewall.service
            echo "  [OK] Firewall configured and enabled"
        else
            echo "  [WARN] yunsh-iptables.sh not found, firewall not configured"
        fi
        touch "$FIREWALL_DONE"
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
install_apt 8 "Qt6 framework" qt6-base-dev qt6-declarative-dev libqt6svg6 qt6-base-dev-tools qt6-qmltooling-plugins qml6 qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtquick-virtualkeyboard qml6-module-qt-labs-qmlmodels qml6-module-qtquick-templates
install_apt 14 "Python environment" python3-pip python3-smbus
pip3 install smbus2 2>/dev/null || true
install_apt 20 "WebEngine" qt6-webengine-dev libqt6webenginequick6
install_apt 26 "Waydroid" lxc python3-dbus waydroid
install_apt 32 "Network & BT" network-manager wpasupplicant bluez bluez-utils
install_apt 38 "System tools" openssh-server avahi-daemon i2c-tools curl wget git
install_apt 44 "Chinese fonts" fonts-noto-cjk
install_apt 50 "Audio" pulseaudio alsa-utils
install_apt 56 "OpenGL" mesa-utils libgl1-mesa-dri

pct 62 "Configuring Waydroid..."
[ -f "/usr/lib/waydroid/data/config.py" ] && timeout 120 waydroid init </dev/null 2>/dev/null || true

pct 68 "Starting core services..."
systemctl enable NetworkManager bluetooth ssh 2>/dev/null || true
systemctl start NetworkManager bluetooth 2>/dev/null || true
systemctl disable dhcpcd 2>/dev/null || true
systemctl stop dhcpcd 2>/dev/null || true

pct 74 "Configuring YUNSH OS..."
mkdir -p /etc/yunsh
cat > /etc/yunsh/version.conf << 'V'
VERSION=v1.0.1
BUILD=2026.07.12
V

pct 78 "Configuring firewall & SSH..."
setup_firewall

pct 84 "Enabling YUNSH services..."
systemctl enable yunsh-os yunsh-network yunsh-bluetooth yunsh-update fstrim.timer 2>/dev/null || true

pct 86 "Creating default user..."
if ! id yunsh &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,dialout yunsh 2>/dev/null || true
    echo "yunsh:yunsh123" | chpasswd 2>/dev/null || true
fi
ssh-keygen -A 2>/dev/null || true
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1 2>/dev/null || true

pct 92 "Installing application store..."
if [ -f /usr/share/yunsh/apps/appstore.apk ]; then
    APK_SIZE=$(stat -c%s /usr/share/yunsh/apps/appstore.apk 2>/dev/null || stat -f%z /usr/share/yunsh/apps/appstore.apk 2>/dev/null || echo 0)
    [ "$APK_SIZE" -gt 100000 ] && waydroid app install /usr/share/yunsh/apps/appstore.apk 2>/dev/null || true
fi

pct 98 "Cleaning up..."
rm -f /usr/bin/yunsh-firstboot.sh /etc/yunsh/.firstboot_partial 2>/dev/null || true

pct 100 "Setup complete! Rebooting..."
touch /etc/yunsh/.packages_installed
sync
sleep 2
reboot
