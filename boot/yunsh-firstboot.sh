#!/bin/bash
# YUNSH OS v1.0 - First Boot Setup
# Installs system packages, initializes Waydroid, sets up the OS
# UI files are pre-injected into the image (see build-image-from-rpi-os.sh)

set -e

# Source progress display (pre-injected)
if [ -f "/usr/bin/yunsh-install-progress.sh" ]; then
    source /usr/bin/yunsh-install-progress.sh
fi

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    [ "$pct" -gt "$1" ] && pct=$1
    if type draw_frame &>/dev/null; then
        draw_frame "$pct" "$2" "$CURRENT_STEP" "$TOTAL_STEPS"
    else
        echo "[$pct%] $2"
    fi
}

# ──────────────────────────────────────────────
echo "============================================"
echo "  YUNSH OS v1.0 - 首次安装"
echo "============================================"

show_progress 8 "更新软件源..."
apt-get update -qq 2>/dev/null || true

show_progress 15 "安装 Qt6 基础框架..."
apt-get install -y -qq \
    qt6-base-dev qt6-declarative-dev libqt6svg6 \
    qt6-base-dev-tools qt6-qmltooling-plugins fbi 2>/dev/null || true

show_progress 25 "安装编译工具..."
apt-get install -y -qq \
    cmake build-essential 2>/dev/null || true

show_progress 30 "安装 Python 环境..."
apt-get install -y -qq \
    python3-pip python3-pyqt6 python3-requests 2>/dev/null || true

show_progress 38 "安装 WebEngine 浏览器引擎..."
apt-get install -y -qq \
    qt6-webengine-dev libqt6webenginequick6 2>/dev/null || true

show_progress 50 "安装 Waydroid Android 容器..."
apt-get install -y -qq \
    lxc python3-dbus waydroid 2>/dev/null || true

show_progress 58 "安装网络与蓝牙组件..."
apt-get install -y -qq \
    network-manager wpasupplicant \
    bluez bluez-utils 2>/dev/null || true

show_progress 65 "安装字体与媒体..."
apt-get install -y -qq \
    fonts-noto-cjk fonts-dejavu-core \
    pulseaudio alsa-utils 2>/dev/null || true

show_progress 75 "启用 YUNSH 系统服务..."
systemctl enable yunsh-os.service 2>/dev/null || true
systemctl enable yunsh-network.service 2>/dev/null || true
systemctl enable yunsh-bluetooth.service 2>/dev/null || true
systemctl enable yunsh-update.service 2>/dev/null || true
# Splash already enabled via rc.local / pre-injection

show_progress 82 "初始化 Waydroid 容器..."
pip3 install waydroid-tools 2>/dev/null || true
waydroid init -s GAPPS -f 2>/dev/null || true

show_progress 90 "安装 应用宝..."

# ───── Wait for Waydroid init to finish ─────
sleep 5

# Install 应用宝 into Waydroid
if [ -f /usr/share/yunsh/apps/appstore.apk ]; then
    APK_SIZE=$(stat -c%s /usr/share/yunsh/apps/appstore.apk 2>/dev/null || stat -f%z /usr/share/yunsh/apps/appstore.apk 2>/dev/null || echo 0)
    if [ "$APK_SIZE" -gt 100000 ]; then
        echo "安装 应用宝 到 Waydroid..."
        waydroid app install /usr/share/yunsh/apps/appstore.apk 2>/dev/null || echo "⚠ 应用宝 安装失败"
    else
        echo "⚠ APK 无效（大小: $APK_SIZE），尝试在线下载..."
        curl -sSL --connect-timeout 15 --max-time 60 -o /tmp/appstore.apk \
            "https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk" \
            2>/dev/null && \
        waydroid app install /tmp/appstore.apk 2>/dev/null || \
        echo "⚠ 在线下载安装失败，可在系统中手动安装"
        rm -f /tmp/appstore.apk
    fi
else
    echo "⚠ 预装 APK 未找到，跳过"
fi


# ───── Enable Waydroid system services ─────
systemctl enable waydroid-container.service 2>/dev/null || true
systemctl enable waydroid.service 2>/dev/null || true

# ───── Enable YUNSH app daemon ─────
systemctl enable yunsh-appd.service 2>/dev/null || true
systemctl enable yunsh-terminal.service 2>/dev/null || true

# ───── Final system config ────────────────
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1

# ───── Mark firstboot complete ────────────
show_progress 100 "✅ 安装完成！正在重启..."
touch /etc/yunsh/.packages_installed
sync
sleep 2

reboot
