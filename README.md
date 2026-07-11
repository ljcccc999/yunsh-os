# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 **Raspberry Pi OS Lite (Debian 13 Trixie)**。
全 visionOS 毛玻璃 UI，AR 透明黑底设计。

> ⬇️ **[下载最新镜像](https://github.com/ljcccc999/yunsh-os/releases)**

```
┌───────────────────────────────────────┐
│        YUNSH OS v1.0 — visionOS       │
├───────────────────────────────────────┤
│  ⚛ 主界面: 动态翻页 + 毛玻璃图标      │
│  📱 Waydroid 安卓兼容 + 应用宝预装    │
│  🌐 WebEngine 浏览器 (GFW-safe)       │
│  📷 相册 + 截图系统                   │
│  🖥 PTY 终端 (持久化会话)             │
│  📡 OTA 双通道更新 (Stable/Beta)      │
│  🎨 全系统 visionOS 毛玻璃设计        │
└───────────────────────────────────────┘
```

---

## 特性

- **visionOS 毛玻璃 UI**: 纯黑 AR 透明背景，全系统毛玻璃面板 + frost 层
- **Waydroid**: 安卓兼容 + 应用宝预装
- **内置浏览器**: Qt6 WebEngine (Chromium)，GFW-safe
- **相册/截图系统**: 自动截图，全屏预览
- **PTY 终端**: 后台持久化会话，切界面不中断
- **OTA 双通道更新**: Stable/Beta，A/B 分区回退
- **首次开机加速**: 自动切换清华镜像源

## 快速开始

### 烧录

```bash
xzcat YUNSH-OS-v1.0.1.img.xz | sudo dd of=/dev/rdisk2 bs=1m status=progress
```

### 硬件

RPi 4B (2GB+) / Pi 5，1080p HDMI 显示，USB 鼠标 + 键盘，16GB+ SD 卡

### 首次开机

1. 插卡通电 → 自动安装依赖（需联网）
2. 重启 → 激活向导（语言/Wi-Fi/账户）
3. 进入主界面

### 操作

**鼠标**: 点击 Home 指示条 → App Switcher | 左键上滑 Home 指示条 → App Switcher
**键盘**: `Escape` 返回 | `Print` 截图 | `Ctrl+↑` App Switcher | `Ctrl+Shift+C` 控制中心

## 构建

**依赖**: macOS + `brew install e2fsprogs` + `pip3 install Pillow`

```bash
git clone git@github.com:ljcccc999/yunsh-os.git
bash scripts/build-image-from-rpi-os.sh
```

产物：`output/YUNSH-OS-v1.0.1.img.xz`（~570MB）

---

## License

© 2024 YUNSH Technology
