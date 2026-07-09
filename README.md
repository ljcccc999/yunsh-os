# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 Raspberry Pi OS Lite (Debian 13 Trixie)。

```
┌───────────────────────────────────────┐
│         YUNSH OS v1.0                  │
├───────────────────────────────────────┤
│  应用层: 设置 · 浏览器 · 应用宝        │
├───────────────────────────────────────┤
│  UI: Qt6/QML 毛玻璃风格 (visionOS 风)  │
├───────────────────────────────────────┤
│  Android: Waydroid + 应用宝            │
├───────────────────────────────────────┤
│  OTA: 双通道更新 (Stable/Beta)         │
├───────────────────────────────────────┤
│  基础: Debian 13 Trixie · Linux 6.6   │
├───────────────────────────────────────┤
│  硬件: 树莓派 4B/5 + 1080p AR 眼镜     │
└───────────────────────────────────────┘
```

## 核心特性

- **🖼️ visionOS 毛玻璃 UI** — 纯黑背景（AR 中透明），高斯模糊面板
- **📱 Waydroid 安卓兼容** — 运行 Android 应用，集成应用宝
- **🌐 OTA 双通道更新** — Stable/Beta 通道 + 大版本开关
- **🖥️ 内置浏览器** — 基于 WebEngine 的 AR 浏览器
- **📸 截图系统** — 截图自动保存
- **♿ 虚拟键盘** — 无物理键盘也可操作

## 首次开机流程

1. **插卡开机** → 自动进入 **激活向导**（内置 Qt6，无需联网）
2. 激活向导：欢迎 → 选择语言 → 配置 Wi-Fi → 输入激活码（可选）
3. 点击 **"开始初始化"** → 自动从 GitHub 下载安装剩余组件
4. 安装完成后重启 → 进入完整 YUNSH OS 桌面 🎉

> **无需网线！** 激活向导内置 Qt6 运行时，Wi-Fi 可在界面内配置。

## 下载与烧录

### 预构建镜像（推荐）

从 [GitHub Releases](https://github.com/ljcccc999/yunsh-os/releases) 下载最新镜像 `.img.xz` 文件。

**Mac 烧录：**

```bash
# 1. 解压
xz -d -k YUNSH-OS-v1.0.0.img.xz

# 2. 查看 SD 卡设备
diskutil list

# 3. 烧录（/dev/rdisk2 替换为你的设备名）
sudo dd if=YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

**Windows 烧录：** 使用 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) 或 [balenaEtcher](https://etcher.balena.io/)。

**哈希校验：**
```bash
shasum -a 256 -c YUNSH-OS-v1.0.0.img.xz.sha256
```

## OTA 系统更新

YUNSH OS 内置 OTA 更新，开机联网后自动检查：

| 功能 | 说明 |
|------|------|
| **Stable 通道** | 仅接收正式版（默认） |
| **Beta 通道** | 可接收测试版更新 |
| **大版本开关** | 关闭后不提示主版本升级 |
| **自动检查** | 开机后定期检测新版本 |

可在 **设置 > 系统更新** 中切换通道和开关。

## 硬件要求

| 要求 | 规格 |
|------|------|
| **主板** | Raspberry Pi 4B (2GB+/4GB/8GB) 或 Pi 5 |
| **显示** | 1080p Micro-OLED AR 眼镜（HDMI 输入） |
| **输入** | USB 鼠标 + 键盘（或触控板） |
| **存储** | 16GB+ SD 卡（建议 A2 级别） |
| **电源** | 5V/3A USB-C |

## 色彩规范

| 用途 | 颜色 |
|------|------|
| 主背景（AR 透明） | `#000000` |
| 毛玻璃面板 | `rgba(20,20,30,0.35) + blur(20px)` |
| 主文字 | `#FFFFFF` |
| 次要文字 | `#A0A0A0` |
| 强调色 | `#00D4FF` |
| 成功 | `#00E676` |
| 警告 | `#FFB300` |
| 错误 | `#FF1744` |

## License

© 2024 YUNSH Technology
