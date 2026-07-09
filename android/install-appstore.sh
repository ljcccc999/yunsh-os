#!/bin/bash
# YUNSH OS v1.0 - Install App Store Script
# Pre-installs 应用宝 (Tencent App Store) into Waydroid container

set -e

echo "=== YUNSH: Installing App Store ==="

# Wait for Waydroid to be ready
echo "Waiting for Waydroid session..."
for i in $(seq 1 30); do
    if waydroid status 2>/dev/null | grep -q "RUNNING"; then
        echo "Waydroid is running"
        break
    fi
    sleep 1
done

# App Store APK path
APK_PATH="/usr/share/yunsh/apps/com.tencent.android.qqdownloader.apk"
APK_URL="https://dlied6.myapp.com/myapp/1104466820/sgame/20191217/com.tencent.android.qqdownloader_latest.apk"

# Download App Store if not present
if [ ! -f "$APK_PATH" ]; then
    echo "Downloading 应用宝 APK..."
    mkdir -p /usr/share/yunsh/apps/
    wget -O "$APK_PATH" "$APK_URL" || {
        echo "WARNING: Failed to download 应用宝 APK"
        echo "You can manually install it later from app.qq.com"
        exit 1
    }
fi

# Install via Waydroid
echo "Installing 应用宝 into Waydroid..."
waydroid app install "$APK_PATH"

# Register App Store as default app market
echo "Registering 应用宝 as default app store..."
waydroid shell "pm grant com.tencent.android.qqdownloader android.permission.INSTALL_PACKAGES"
waydroid shell "settings put secure default_app_store com.tencent.android.qqdownloader"

echo "=== App Store installation complete ==="
echo "应用宝 is now available in your app list."
