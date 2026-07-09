#!/bin/bash
# YUNSH OS v1.0 - First Boot Setup
# Installs everything with progress display, then reboots.

set -e

# Source progress display
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
if [ -f "/usr/bin/yunsh-install-progress.sh" ]; then
    source /usr/bin/yunsh-install-progress.sh
else
    # Define minimal progress function if script not available yet
    draw_frame() { echo "[$1%] $2"; }
fi

# Progress tracking
TOTAL_STEPS=12
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    [ "$pct" -gt "$1" ] && pct=$1
    draw_frame "$pct" "$2" "$CURRENT_STEP" "$TOTAL_STEPS"
}

# ──────────────────────────────────────────────
show_progress 5 "正在更新软件源..."
apt-get update -qq 2>/dev/null || true

show_progress 8 "正在升级系统包..."
apt-get upgrade -y -qq 2>/dev/null || true

show_progress 15 "正在安装 Qt6 基础框架..."
apt-get install -y -qq \
    qt6-base-dev qt6-declarative-dev libqt6svg6 \
    qt6-base-dev-tools qt6-qmltooling-plugins 2>/dev/null || true

show_progress 25 "正在安装编译工具..."
apt-get install -y -qq \
    cmake build-essential 2>/dev/null || true

show_progress 30 "正在安装 Python 环境..."
apt-get install -y -qq \
    python3-pip python3-pyqt6 python3-requests 2>/dev/null || true

show_progress 38 "正在安装 WebEngine 浏览器引擎..."
apt-get install -y -qq \
    qt6-webengine-dev libqt6webenginequick6 2>/dev/null || true

show_progress 45 "正在安装 Waydroid Android 容器..."
apt-get install -y -qq \
    lxc python3-dbus waydroid 2>/dev/null || true

show_progress 52 "正在安装网络与蓝牙组件..."
apt-get install -y -qq \
    network-manager wpasupplicant \
    bluez bluez-utils 2>/dev/null || true

show_progress 58 "正在安装输入设备驱动..."
apt-get install -y -qq \
    libinput-bin libinput-tools evtest 2>/dev/null || true

show_progress 62 "正在安装字体..."
apt-get install -y -qq \
    fonts-noto-cjk fonts-dejavu-core 2>/dev/null || true

show_progress 66 "正在安装媒体与截图工具..."
apt-get install -y -qq \
    pulseaudio alsa-utils \
    imagemagick scrot x11-utils 2>/dev/null || true

show_progress 72 "正在创建系统目录..."
mkdir -p /usr/share/yunsh/{logo,ui,icons,apps}
mkdir -p /etc/yunsh
touch /var/log/yunsh-update.log
touch /var/log/yunsh-network.log
touch /var/log/yunsh-bluetooth.log

# Download YUNSH components from GitHub
show_progress 76 "正在下载 UI 组件..."
YUNSH_REPO="https://raw.githubusercontent.com/ljcccc999/yunsh-os/main"

# UI files (all QML)
for f in main.qml HomeScreen.qml SettingsScreen.qml AboutScreen.qml \
  AppDock.qml AppIcon.qml GlassPanel.qml GlassCard.qml \
  GlassEffect.qml DropShadowEffect.qml StatusBar.qml ControlCenter.qml \
  UpdateScreen.qml UpdateHistoryScreen.qml NetworkScreen.qml BluetoothScreen.qml \
  YunshBrowser.qml YunshMetaverse.qml ScreenshotOverlay.qml \
  ActivationScreen.qml SystemInfoScreen.qml VirtualKeyboard.qml Screensaver.qml; do
  curl -s "${YUNSH_REPO}/ui/${f}" -o "/usr/share/yunsh/ui/${f}" &
done

# Icons
for f in settings.svg appstore.svg files.svg about.svg wifi.svg \
  bluetooth.svg update.svg metaverse.svg screenshot.svg; do
  curl -s "${YUNSH_REPO}/ui/icons/${f}" -o "/usr/share/yunsh/icons/${f}" &
done

# System scripts
for f in yunsh-update-daemon.py yunsh-updater.py yunsh-network-daemon.py \
  yunsh-bluetooth-daemon.py yunsh-screenshotd yunsh-factory-reset; do
  curl -s "${YUNSH_REPO}/system/${f}" -o "/usr/bin/${f}" &
done

wait
chmod +x /usr/bin/yunsh-update-daemon.py /usr/bin/yunsh-updater.py \
  /usr/bin/yunsh-network-daemon.py /usr/bin/yunsh-bluetooth-daemon.py \
  /usr/bin/yunsh-screenshotd /usr/bin/yunsh-factory-reset

show_progress 84 "正在配置系统..."
cat > /etc/yunsh/update.conf << 'UC'
auto_update=false
wifi_only=true
update_channel=stable
# update_channel: stable | beta
#   stable - only receive stable releases
#   beta   - also receive prerelease (beta) versions
UC

show_progress 88 "正在初始化 Waydroid 容器..."
pip3 install waydroid-tools || true
waydroid init -s GAPPS -f 2>/dev/null || true

show_progress 92 "正在安装应用宝..."
cat > /usr/bin/install-appstore.sh << 'INSTALL_AS'
#!/bin/bash
echo "Downloading 应用宝..."
APK_URL="https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk"
wget -q -O /usr/share/yunsh/apps/appstore.apk "$APK_URL" 2>/dev/null || {
  echo "Download failed - try manual install"
  echo "Visit: https://sj.qq.com/"
  exit 1
}
echo "Installing into Waydroid..."
waydroid app install /usr/share/yunsh/apps/appstore.apk
echo "应用宝 installed successfully!"
INSTALL_AS
chmod +x /usr/bin/install-appstore.sh

# Install 应用宝 automatically
/usr/bin/install-appstore.sh

show_progress 95 "正在创建启动器..."
cat > /usr/bin/yunsh-ui-launcher << 'L'
#!/bin/bash
cd /usr/share/yunsh/ui

if [ ! -f /etc/yunsh/.activated ]; then
    # First boot activation wizard
    QT_QPA_PLATFORM=eglfs QT_QPA_EGLFS_INTEGRATION=eglfs_kms \
    QT_QUICK_BACKEND=software qml main.qml
    # Activation completed, write flag
    touch /etc/yunsh/.activated
    sync
fi

# Main UI (subsequent boots)
QT_QPA_PLATFORM=eglfs QT_QPA_EGLFS_INTEGRATION=eglfs_kms \
QT_QUICK_BACKEND=software qml main.qml
L
chmod +x /usr/bin/yunsh-ui-launcher

# YUNSH main UI service
cat > /etc/systemd/system/yunsh-os.service << 'SVC'
[Unit]
Description=YUNSH OS v1.0 AR Glasses UI
After=graphical.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-ui-launcher
Restart=always
User=root
[Install]
WantedBy=graphical.target
SVC
systemctl enable yunsh-os.service

# Network daemon service
cat > /etc/systemd/system/yunsh-network.service << 'NSVC'
[Unit]
Description=YUNSH OS Network Manager
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-network-daemon.py
Restart=on-failure
RestartSec=15
User=root
[Install]
WantedBy=multi-user.target
NSVC
systemctl enable yunsh-network.service

# Bluetooth daemon service
cat > /etc/systemd/system/yunsh-bluetooth.service << 'BSVC'
[Unit]
Description=YUNSH OS Bluetooth Manager
After=bluetooth.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-bluetooth-daemon.py
Restart=on-failure
RestartSec=15
User=root
[Install]
WantedBy=multi-user.target
BSVC
systemctl enable yunsh-bluetooth.service

# Update daemon service
cat > /etc/systemd/system/yunsh-update.service << 'USVC'
[Unit]
Description=YUNSH OS Update Daemon
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/yunsh-update-daemon.py
Restart=on-failure
RestartSec=30
User=root
[Install]
WantedBy=multi-user.target
USVC
systemctl enable yunsh-update.service

# Boot splash
cat > /etc/systemd/system/yunsh-splash.service << 'SPLASH'
[Unit]
Description=YUNSH Splash Screen
DefaultDependencies=no
Before=display-manager.service
[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-splash
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
SPLASH

cat > /usr/bin/yunsh-splash << 'SP'
#!/bin/bash
echo -e "\e[32m"
echo "  YYYY  UU   UU  NNNN   SSS  H   H"
echo "   YY   UU   UU  NN NN  SS    H   H"
echo "   YY   UU   UU  NN NN  SSS   HHHHH"
echo "   YY   UU   UU  NN NN    SS  H   H"
echo "   YY    UUUUU   NN NN  SSS   H   H"
echo -e "\e[0m"
echo "  YUNSH OS v1.0"
echo "  AR Glasses Operating System"
SP
chmod +x /usr/bin/yunsh-splash
systemctl enable yunsh-splash.service

# Auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AL'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
AL

# Hostname
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1

show_progress 100 "✅ 安装完成！正在重启..."
sleep 2

# Mark setup complete
touch /etc/yunsh/.installed
reboot
