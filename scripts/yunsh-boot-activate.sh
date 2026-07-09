#!/bin/bash
# YUNSH OS v1.0 - First Boot Activation Launcher
# Runs the activation wizard with Qt6 QML (baked into image)
# After activation, triggers full system installation

cd /usr/share/yunsh/ui

# Show activation wizard
QT_QPA_PLATFORM=eglfs \
QT_QPA_EGLFS_INTEGRATION=eglfs_kms \
QT_QUICK_BACKEND=software \
qml main.qml --activate

# After activation completes, write flag and start firstboot
touch /etc/yunsh/.activated

# Run firstboot to install remaining packages
if [ -x /usr/bin/yunsh-firstboot.sh ]; then
    /usr/bin/yunsh-firstboot.sh
fi

# After firstboot completes, reboot into main UI
reboot
