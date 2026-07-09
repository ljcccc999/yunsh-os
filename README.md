# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 **Raspberry Pi OS Lite (Debian 13 Trixie)**。

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

从 [GitHub Releases](https://github.com/ljcccc999/yunsh-os/releases) 下载最新镜像：

```bash
# 1. 解压
xz -d -k YUNSH-OS-v1.0.0.img.xz

# 2. 查看 SD 卡设备
diskutil list

# 3. 烧录（/dev/rdisk2 替换为你的设备）
sudo dd if=YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

### 哈希校验
```bash
shasum -a 256 -c YUNSH-OS-v1.0.0.img.xz.sha256
```

## 目录结构

```
yunsh-os/
├── boot/               # 启动配置 (config.txt, kms-config.json)
├── scripts/            # 构建 & 刷写脚本
│   ├── build-image-from-rpi-os.sh   # 从 RPi OS 构建镜像
│   ├── yunsh-boot-activate.sh       # 首启动激活脚本 (内置 Qt6)
│   └── flash-mac.sh                 # Mac 端刷写脚本
├── system/             # 系统守护进程
│   ├── yunsh-update-daemon.py       # OTA 更新守护进程
│   ├── yunsh-updater.py             # OTA 更新器 (A/B分区)
│   ├── yunsh-firstboot.sh           # 首启动安装脚本
│   ├── yunsh-boot-activate.sh       # 首启动激活脚本
│   ├── yunsh-network-daemon.py      # 网络管理
│   ├── yunsh-bluetooth-daemon.py    # 蓝牙管理
│   ├── yunsh-install-progress.sh    # 安装进度显示
│   ├── S01yunsh-boot               # 启动 service
│   └── S02yunsh-update             # 更新 service
├── ui/                 # Qt6 QML 用户界面
│   ├── main.qml                     # 主入口
│   ├── ActivationScreen.qml         # 激活向导
│   ├── HomeScreen.qml               # 主屏幕
│   ├── SettingsScreen.qml           # 设置
│   ├── UpdateScreen.qml             # 系统更新
│   ├── NetworkScreen.qml            # Wi-Fi 管理
│   ├── BluetoothScreen.qml          # 蓝牙管理
│   ├── StatusBar.qml                # 状态栏
│   ├── ControlCenter.qml            # 控制中心
│   ├── VirtualKeyboard.qml          # 虚拟键盘
│   ├── GlassCard.qml / GlassPanel.qml # 毛玻璃组件
│   ├── Screensaver.qml              # 待机屏幕
│   ├── AppDock.qml / AppIcon.qml    # 应用坞
│   ├── YunshBrowser.qml             # 浏览器
│   ├── YunshMetaverse.qml           # 元宇宙
│   └── icons/                       # SVG 图标集
├── compositor/         # C++ 显示合成器 (DRM/EGL/GLES)
├── android/            # Waydroid 配置
│   ├── waydroid.cfg                 # Waydroid 配置
│   ├── yunsh-android-bridge.py      # 安卓桥接
│   └── install-appstore.sh          # 安装应用宝
└── logo/               # YUNSH 品牌 Logo
```

## OTA 更新系统

YUNSH OS 内置 **双通道 OTA 更新**：

| 功能 | 说明 |
|------|------|
| **Stable 通道** | 仅接收正式版（Release 非 prerelease） |
| **Beta 通道** | 接收测试版 + 正式版（含 prerelease） |
| **大版本开关** | 关闭后跳过主版本号升级（如 v1→v2） |
| **A/B 分区** | `mmcblk0p2` (A) / `mmcblk0p3` (B)，故障安全回退 |
| **全量更新** | 下载完整镜像 → 写入备用分区 → 标记切换 |

通道可在 **设置 > 系统更新** 中随时切换。

### 开发新版本

```bash
# 1. 修改代码 → 提交
git add .
git commit -m "v1.1.0: 新功能..."

# 2. 打标签
git tag v1.1.0
git push origin main --tags

# 3. 上传 Release
gh release create v1.1.0 \
  --title "YUNSH OS v1.1.0" \
  --notes "更新内容..." \
  output/YUNSH-OS-v1.1.0.img.xz

# 测试版（勾 --prerelease）
gh release create v1.1.0-beta \
  --title "YUNSH OS v1.1.0 Beta" \
  --prerelease \
  output/YUNSH-OS-v1.1.0-beta.img.xz
```

## 构建镜像

```bash
# 配置
export RPIZ_IMAGE="raspios-lite.img"
export OUTPUT_IMAGE="output/YUNSH-OS-v1.0.0.img"

# 构建
./scripts/build-image-from-rpi-os.sh
```

构建流程：
1. 下载 Raspberry Pi OS Lite (arm64)
2. 注入 Qt6 运行时 + QML 模块
3. 注入 YUNSH 激活脚本 + UI 文件
4. 配置首启动 systemd 服务
5. 压缩为 `.img.xz` 输出

## 硬件要求

| 要求 | 规格 |
|------|------|
| **主板** | Raspberry Pi 4B (2GB+/4GB/8GB) 或 Pi 5 |
| **显示** | 1080p Micro-OLED AR 眼镜（HDMI） |
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
