# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 **Raspberry Pi OS Lite (Debian 13 Trixie)**。

> ⬇️ **[下载最新镜像](https://github.com/ljcccc999/yunsh-os/releases)** — 前往 Releases 页面下载 `.img.xz` 文件

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

---

## 📖 用户指南

### 核心特性

- **🖼️ visionOS 毛玻璃 UI** — 纯黑背景（AR 中透明），高斯模糊面板
- **📱 Waydroid 安卓兼容** — 运行 Android 应用，集成应用宝
- **🌐 OTA 双通道更新** — Stable/Beta 通道 + 大版本开关
- **🖥️ 内置浏览器** — 基于 WebEngine 的 AR 浏览器
- **📸 截图系统** — 截图自动保存
- **♿ 虚拟键盘** — 无物理键盘也可操作

### 首次开机流程

1. **插卡通电** → systemd 自动启动 `yunsh-os.service`
2. **第一次开机**: 联网安装 Qt6/Waydroid/应用宝等依赖（全自动）
3. **自动重启**
4. **第二次开机**: 进入 YUNSH 激活向导（visionOS 毛玻璃 UI）
   - 欢迎页面 → 下一步
   - 选择语言（中文 / English）
   - 配置 Wi-Fi
   - 激活完成
5. 进入 **YUNSH 主界面** 🎯

> ⚠️ **第一次开机需要联网**（apt-get install 装包），之后全程离线可用。

### 下载与烧录

#### 方法一：预构建镜像（推荐）

从 [GitHub Releases](https://github.com/ljcccc999/yunsh-os/releases) 下载最新镜像文件 `YUNSH-OS-vX.X.X.img.xz`。

**Mac 烧录步骤：**

```bash
# 1. 解压镜像
xz -d -k YUNSH-OS-v1.0.0.img.xz

# 2. 查看 SD 卡设备号
diskutil list

# 3. 烧录（/dev/rdisk2 替换为你的设备名）
sudo dd if=YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

**Windows 烧录：** 推荐使用 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) 或 [balenaEtcher](https://etcher.balena.io/)，选择下载的 `.img.xz` 文件直接烧录。

**哈希校验：** 下载后校验文件完整性

```bash
shasum -a 256 -c YUNSH-OS-v1.0.0.img.xz.sha256
```

#### 方法二：使用烧录脚本

```bash
# 需要先安装依赖
brew install xz e2fsprogs

# 插入 SD 卡后运行
./scripts/flash-mac.sh
```

### OTA 系统更新

YUNSH OS 内置 OTA 在线更新功能，开机联网后自动检测：

| 功能 | 说明 |
|------|------|
| **Stable 通道（默认）** | 仅接收正式版更新 |
| **Beta 通道** | 可接收测试版 + 正式版更新 |
| **大版本开关** | 关闭后不接收主版本号升级（如 v1→v2） |
| **自动检查** | 开机后定期检测新版本 |
| **A/B 分区更新** | 更新失败可回退到旧版本 |

切换通道和开关位置：**设置 → 系统更新**

### 硬件要求

| 要求 | 规格 |
|------|------|
| **主板** | Raspberry Pi 4B (2GB+/4GB/8GB) 或 Pi 5 |
| **显示** | 1080p Micro-OLED 单目 AR 眼镜（HDMI 输入） |
| **输入** | USB 鼠标 + 键盘（或触控板） |
| **存储** | 16GB+ SD 卡（建议 Class 10 / A2 级别） |
| **电源** | 5V/3A USB-C 电源适配器 |

### 色彩规范

| 用途 | 颜色 |
|------|------|
| 主背景（AR 中透明） | `#000000` |
| 毛玻璃面板 | `rgba(20,20,30,0.35) + blur(20px)` |
| 主文字 | `#FFFFFF` |
| 次要文字 | `#A0A0A0` |
| 强调色 | `#00D4FF`（青色） |
| 成功 | `#00E676`（绿色） |
| 警告 | `#FFB300`（橙色） |
| 错误 | `#FF1744`（红色） |

---

## 🔧 开发者指南

### 目录结构

```
yunsh-os/
├── boot/                    # 启动配置
│   ├── config.txt           # 树莓派启动配置
│   └── kms-config.json      # KMS 显示配置
│
├── scripts/                 # 构建 & 刷写脚本
│   ├── build-image-from-rpi-os.sh   # 从 RPi OS 构建镜像（主构建脚本）
│   ├── build-image-workflow.yml     # GitHub Actions 自动构建
│   ├── yunsh-boot-activate.sh       # 首启动激活脚本
│   ├── flash-mac.sh                 # Mac 端一键刷写
│   ├── process-logo.sh              # 品牌 Logo 处理
│   └── process-logo.py              # Logo 处理辅助脚本
│   ├── yunsh-update-daemon.py       # OTA 更新守护进程（后台检查更新）
│   ├── yunsh-updater.py             # OTA 更新器（A/B 分区写入）
│   ├── yunsh-firstboot.sh           # 首启动安装脚本
│   ├── yunsh-boot-activate.sh       # 首启动激活脚本（旧）
│   ├── yunsh-network-daemon.py      # 网络管理守护进程
│   ├── yunsh-bluetooth-daemon.py    # 蓝牙管理守护进程
│   ├── yunsh-install-progress.sh    # 安装进度显示
│   ├── yunsh-factory-reset          # 重置到出厂状态
│   ├── yunsh-inputd                 # 输入设备管理
│   ├── yunsh-powerd                 # 电源管理
│   ├── yunsh-screenshotd            # 截图守护进程
│   ├── yunsh-launcher.cpp           # C++ 启动器
│   ├── S01yunsh-boot                # systemd oneshot：首次启动激活
│   └── S02yunsh-update              # systemd oneshot：更新检查
│
├── ui/                      # Qt6 QML 用户界面
│   ├── main.qml                     # 主入口
│   ├── main.cpp                     # C++ 入口
│   ├── CMakeLists.txt               # Qt6 构建配置
│   │
│   ├── 主屏幕
│   │   ├── HomeScreen.qml           # 主屏幕
│   │   ├── AppDock.qml              # 底部应用坞
│   │   └── AppIcon.qml              # 应用图标组件
│   │
│   ├── 启动向导
│   │   ├── ActivationScreen.qml     # 激活向导（欢迎→语言→Wi-Fi→激活码）
│   │   └── AboutScreen.qml          # 关于本机页面
│   │
│   ├── 系统设置
│   │   ├── SettingsScreen.qml       # 设置页面
│   │   ├── NetworkScreen.qml        # Wi-Fi 管理
│   │   ├── BluetoothScreen.qml      # 蓝牙管理
│   │   ├── SystemInfoScreen.qml     # 系统信息
│   │   ├── UpdateScreen.qml         # 系统更新
│   │   └── UpdateHistoryScreen.qml  # 更新历史
│   │
│   ├── UI 组件
│   │   ├── StatusBar.qml            # 状态栏（时间、电量、信号）
│   │   ├── ControlCenter.qml        # 控制中心
│   │   ├── VirtualKeyboard.qml      # 虚拟键盘
│   │   ├── Screensaver.qml          # 待机屏幕
│   │   ├── ScreenshotOverlay.qml    # 截图反馈
│   │   ├── GlassCard.qml            # 毛玻璃卡片
│   │   └── GlassPanel.qml           # 毛玻璃面板
│   │
│   ├── 应用
│   │   ├── YunshBrowser.qml         # 内置浏览器
│   │   └── YunshMetaverse.qml       # 元宇宙页面（预留）
│   │
│   └── icons/                       # SVG 图标集
│       ├── about.svg
│       ├── appstore.svg
│       ├── bluetooth.svg
│       ├── files.svg
│       ├── metaverse.svg
│       ├── screenshot.svg
│       ├── settings.svg
│       ├── update.svg
│       └── wifi.svg
│
├── compositor/              # C++ 显示合成器
│   ├── main.cpp                     # 入口
│   ├── compositor.cpp / .h          # 合成器核心
│   ├── CMakeLists.txt               # 构建配置
│   └── shaders/
│       ├── fullscreen.vert          # 全屏顶点着色器
│       └── glass.frag               # 毛玻璃片段着色器
│
├── android/                 # Waydroid 安卓兼容
│   ├── waydroid.cfg                 # Waydroid 配置
│   ├── yunsh-android-bridge.py      # 安卓桥接服务
│   └── install-appstore.sh          # 安装应用宝
│
├── logo/                    # 品牌 Logo（多尺寸）
│   ├── logo-32.png
│   ├── logo-64.png
│   ├── logo-128.png
│   ├── logo-256.png
│   ├── logo-512.png
│   └── logo-full.png
│
├── .gitignore
└── README.md                 # 本文件
```

### 系统架构

#### 启动流程详解

```
上电开机
  ↓
Raspberry Pi Bootloader
  ↓
config.txt (1080p, KMS) 配置
  ↓
Linux 6.6 内核启动 → systemd
  ↓
yunsh-os.service → yunsh-ui-launcher
  ↓
┌─ 检测 /etc/yunsh/.activated ──────┐
│                                    │
├─ 未激活（首次开机） ───────────────┤
│  yunsh-firstboot.sh 运行            │
│    ├ 更新源 & 安装 Qt6               │
│    ├ 安装 Waydroid 容器              │
│    ├ 安装应用宝                      │
│    └ 安装蓝牙/网络/字体等依赖         │
│  ↑ 需要联网首次安装                  │
│    ↓                               │
│  写入 .activated 标志                │
│  重启                               │
│                                    │
├─ 已激活 ───────────────────────────┤
│  qml main.qml (Qt6 QML 渲染器)      │
│    ↓                               │
│  ActivationScreen.qml 激活向导       │
│    ├ 欢迎页面 (visionOS 毛玻璃)      │
│    ├ 选择语言/键盘                    │
│    ├ 连接 Wi-Fi                      │
│    └ 初始化进度条                     │
│    ↓                               │
│  HomeScreen.qml → YUNSH 桌面        │
│    ├ 状态栏 + 控制中心               │
│    ├ 设置 / 浏览器 / Metaverse       │
│    ├ 应用宝 / 文件管理器             │
│    └ 后台 daemon (网络/蓝牙/更新)    │
└────────────────────────────────────┘
```

#### OTA 更新系统详解

YUNSH OS 内置双通道 A/B 分区 OTA 更新，确保更新安全。

**更新检测流程：**

```
yunsh-update-daemon.py（开机启动，每 6 小时自动检查一次）
  │
  ├─ Stable 通道（默认）
  │   GET /repos/ljcccc999/yunsh-os/releases/latest
  │   只返回非 prerelease 的最新版本
  │
  ├─ Beta 通道
  │   GET /repos/ljcccc999/yunsh-os/releases?per_page=5
  │   返回最新的 5 个 Release（含 prerelease 测试版）
  │   取其中版本号最高的一个
  │
  ├─ 版本比较
  │   compare_versions(latest, current)
  │   ├─ latest > current → 有更新
  │   ├─ latest == current → 已是最新
  │   └─ latest < current → 不处理
  │
  ├─ 大版本检查
  │   is_major_update(current, latest)
  │   比较主版本号（v1→v2 → 大版本）
  │   ├─ allow_major_update = false → 跳过
  │   └─ allow_major_update = true → 正常提示
  │
  └─ 通知用户 → 设置页面显示"有可用更新"
```

**用户确认更新后：**

```
yunsh-updater.py 启动
  │
  ├─ 1. 下载镜像
  │    从 GitHub Release 下载 .img.xz 文件
  │    显示下载进度
  │
  ├─ 2. 解压镜像
  │    xz -d YUNSH-OS-v1.1.0.img.xz → YUNSH-OS-v1.1.0.img
  │
  ├─ 3. 确定目标分区
  │    当前从 mmcblk0p2 启动 → 写入 mmcblk0p3
  │    当前从 mmcblk0p3 启动 → 写入 mmcblk0p2
  │
  ├─ 4. 写入镜像
  │    dd if=new-image.img of=/dev/mmcblk0pX bs=4M
  │    显示写入进度
  │
  ├─ 5. 标记安装
  │    mount 目标分区
  │    写入 /etc/yunsh/.installed（标记已安装）
  │    写入 /etc/yunsh/.activated（跳过激活向导）
  │    umount
  │
  ├─ 6. 切换启动分区
  │    修改 config.txt 中的启动分区配置
  │
  └─ 7. 重启
      reboot → 从新分区启动
```

### 镜像构建策略

YUNSH OS 镜像在 macOS 上通过以下方式构建：

**构建流程：**

```
RPi OS Lite 镜像
  ↓ cp 复制工作副本
  ↓ hdiutil 挂载 boot 分区 (FAT32)
  ├─ 写入 config.txt (1080p, KMS, 显示配置)
  └─ 复制 yunsh-firstboot.sh
  ↓ 提取 root 分区 (ext4)
  ├─ debugfs 批量注入:
  │ ├ 23 个 QML UI 文件       → /usr/share/yunsh/ui/
  │ ├ 9 个 SVG 图标            → /usr/share/yunsh/icons/
  │ ├ 6 个 Logo PNG            → /usr/share/yunsh/logo/
  │ ├ 10 个系统脚本/daemon     → /usr/bin/
  │ ├ 5 个 systemd 服务文件   → /etc/systemd/system/
  │ ├ 启动器/闪屏/rc.local     → /usr/bin/
  │ ├ autologin 配置           → /etc/systemd/system/
  │ └ hostname → yunsh-v1      → /etc/hostname
  ├─ symlink 启用 yunsh-os.service
  └─ 设置 0755 可执行权限
  ↓ dd 写回 ext4 → 成品镜像
```

**关键依赖：** macOS 上需安装 `e2fsprogs`（`brew install e2fsprogs`）来提供 `debugfs` 工具，用于直接操作 ext4 分区。

### 构建镜像

#### 前置条件

- **操作系统：** macOS
- **依赖工具：**
  - `e2fsprogs`（`brew install e2fsprogs`）— 提供 `debugfs` 用于 ext4 文件操作
  - `xz`（macOS 自带或 `brew install xz`）
- **基础镜像：** Raspberry Pi OS Lite (Debian 13 Trixie) arm64
  - 下载后放到 `build/` 目录
  - curl -LO https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-最新版本/文件

### 构建命令

```bash
# 1. 下载并放置 RPi OS Lite 镜像到 build/ 目录
# 2. 执行构建（macOS）
bash scripts/build-image-from-rpi-os.sh
# 3. 烧录到 SD 卡
sudo dd if=output/YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

### 开发注意事项

#### Git 管理

- `build/` 目录不要提交（含 RPi OS 原始镜像，约 2.8GB）
- `.deb` 安装包不要提交
- 已配置 `.gitignore` 排除上述文件

#### 本地开发流程

```bash
# 每次修改后验证
./scripts/build-image-from-rpi-os.sh

# 烧录测试
xz -d -k output/YUNSH-OS-v1.0.0.img.xz
sudo dd if=output/YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

#### 常见问题

**Q: 构建时提示 `debugfs: command not found`**
A: 安装 e2fsprogs：`brew install e2fsprogs`

**Q: 首启动激活向导不显示**
A: 检查 `/etc/yunsh/.activated` 是否已存在，删除后重启

**Q: OTA 更新失败**
A: 检查网络连接，确认 GitHub Releases 页面存在对应版本

**Q: 烧录后树莓派不启动**
A: 确认 SD 卡 ≥ 16GB，镜像解压正常，使用 sha256 校验文件完整性

---

### Developer

Tim（LiuJiacheng）

### License

© 2024 YUNSH Technology
