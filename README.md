# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 **Raspberry Pi OS Lite (Debian 13 Trixie)**。
全 visionOS 毛玻璃 UI，AR 透明黑底设计。

<p align="center">
  <img src="logo/logo-256.png" width="128" alt="YUNSH Logo"/>
</p>

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

## ✨ 特性

### 🖼️ visionOS 毛玻璃 UI
- 纯黑 AR 透明背景
- 完美圆形毛玻璃图标 (60×60, radius: 30)
- 全系统毛玻璃面板 + frost 层 + 顶光 + DropShadow
- iOS 式动态翻页主屏（超 8 个 App 自动新增页）
- 玻璃 orb 时钟 widget
- 系统级 iOS 长按复制/粘贴菜单

### 📱 Waydroid 安卓兼容
- 预装 **应用宝**（腾讯应用商店）
- Python HTTP daemon (:8590) 启动 Android 应用
- 无缝 QML ↔ Android 切换

### 🌐 内置浏览器
- Qt6 WebEngine（Chromium 真实网页渲染）
- 导航按钮 · 自动 HTTPS → HTTP fallback
- Bing 搜索 · 加载进度条
- `Ctrl+L` URL 栏 · iOS 长按菜单

### 📷 相册
- 自动读取截图目录 `~/Pictures/Screenshots/`
- 5 列毛玻璃缩略图网格
- 全屏预览 + 删除/保存工具栏

### 🖥 内置终端
- Python PTY HTTP 后端 (:8591)
- 会话持久化（切界面不中断）
- 长按复制/粘贴

### 📡 OTA 双通道更新
- Stable / Beta 双通道 + 大版本开关
- **GFW-safe**: 国内可用的 OTA 下载
- 走 `api.github.com`（GFW 可通）
- `release-assets.githubusercontent.com`（直连）
- A/B 分区更新，失败可回退

### 🚀 首次开机加速
- 自动检测 `deb.debian.org` → 切换清华镜像源
- 全自动 Qt6 / Waydroid / 应用宝安装

---

## 📦 系统组件

### 7 个 systemd 服务

| 服务 | 说明 |
|------|------|
| `yunsh-os` | UI 启动器（QML 主入口） |
| `yunsh-splash` | Apple 式两段 splash |
| `yunsh-network` | Wi-Fi 扫描/连接管理 |
| `yunsh-bluetooth` | 蓝牙设备管理 |
| `yunsh-update` | OTA 更新守护 |
| `yunsh-appd` | Waydroid 应用启动代理 |
| `yunsh-terminal` | PTY 终端后台 |

### 29 个 QML 文件

主界面 · 激活向导 · 设置 · 浏览器 · 相册 · 终端 · 元宇宙
控制中心 · 状态栏 · Dock · 毛玻璃组件 · 长按菜单 · 虚拟键盘 · 屏保 · 截图

---

## 🚀 快速开始

### 下载镜像

从 [Releases](https://github.com/ljcccc999/yunsh-os/releases) 下载 `YUNSH-OS-v1.0.0.img.xz`

### 烧录

```bash
# macOS
xz -d -k YUNSH-OS-v1.0.0.img.xz
sudo dd if=YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress

# 或用脚本
./scripts/flash-mac.sh
```

### 首次开机

1. 插卡通电 → 自动装包（需联网）
2. 重启 → 激活向导（语言/Wi-Fi/创建账户）
3. 进入 YUNSH 主界面 🎯

### 硬件要求

- **主板**: Raspberry Pi 4B (2GB+) 或 Pi 5
- **显示**: 1080p Micro-OLED 单目 AR 眼镜（HDMI）
- **输入**: USB 鼠标 + 键盘
- **存储**: 16GB+ SD 卡（建议 A2）
- **电源**: 5V/3A USB-C

---

## 👨‍💻 开发者指南

### 环境要求

- **操作系统**: macOS（构建主机，其他系统需要改脚本）
- **依赖工具**:
  - `e2fsprogs` → `brew install e2fsprogs`（提供 `debugfs`，用于 ext4 文件操作）
  - `xz` → macOS 自带，或 `brew install xz`
  - Python3 + Pillow → `pip3 install Pillow`（生成 splash 帧缓冲）

### 完整构建流程

```bash
# 1. 克隆仓库
git clone git@github.com:ljcccc999/yunsh-os.git
cd yunsh-os

# 2. 下载 RPi OS Lite arm64 镜像
#    放到 build/ 目录，文件名例如 2026-05-27-raspios-bookworm-arm64-lite.img
#    下载地址: https://www.raspberrypi.com/software/operating-systems/

# 3. 执行构建
bash scripts/build-image-from-rpi-os.sh

# 4. 构建产物
#    output/YUNSH-OS-v1.0.0.img  →  完整 ext4 镜像
#    自动压缩为 output/YUNSH-OS-v1.0.0.img.xz (~570MB)

# 5. 本地烧录测试
sudo dd if=output/YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

### 构建做了什么

构建脚本在 macOS 上用 `debugfs` 直接操作 ext4 分区，不依赖 Docker 或虚拟机：

1. 解包 RPi OS Lite 镜像 → 分离 boot (FAT32) 和 root (ext4) 分区
2. `boot/config.txt` → 写 1080p KMS + `disable_splash=1`
3. `debugfs` 向 ext4 批量注入:
   - 29 个 QML 文件 → `/usr/share/yunsh/ui/`
   - 11 个 SVG 图标 → `/usr/share/yunsh/icons/`
   - 6 个 logo PNG → `/usr/share/yunsh/logo/`
   - 10 个系统脚本 → `/usr/bin/`
   - 7 个 systemd 服务 → `/etc/systemd/system/`
   - 版本配置 → `/etc/yunsh/version.conf`
4. `debugfs` symlink enable systemd 服务
5. 设置所有文件 0755 权限
6. 配置 autologin + hostname `yunsh-v1`
7. 生成 splash 帧缓冲 (Python + PIL)
8. 合并回成品镜像

### 构建耗时

| 阶段 | 时间 |
|------|------|
| 解包 + 挂载 | ~5s |
| 注入文件 | ~15s |
| 生成 splash | ~3s |
| 合并镜像 | ~10s |
| **总计** | **~35s** |

### 自定义系统

你可以修改以下内容来打造自己的 YUNSH OS：

#### 改 UI
```bash
# 编辑 QML 文件后直接构建即可
vim ui/HomeScreen.qml          # 主界面布局
vim ui/SettingsScreen.qml      # 设置页面
vim ui/YunshBrowser.qml        # 浏览器
vim ui/ActivationScreen.qml    # 激活向导
vim ui/StatusBar.qml           # 状态栏
vim ui/AppIcon.qml             # 图标样式
```

#### 增加 App
编辑 `ui/HomeScreen.qml` 的 `appList` 数组：
```qml
property var appList: [
    { name: "设置", icon: "settings.svg", color: "#00D4FF", action: "settings" },
    { name: "你的App", icon: "yourapp.svg", color: "#FF5722", action: "yourapp" }
    // ↑ 超过 8 个自动新增一页
]
```

#### 改开机画面
```bash
# 修改 splash 生成参数
vim system/yunsh-fb-splash.py

# 或直接换 logo
cp your-logo.png logo/logo-256.png
```

#### 改 OTA 更新服务器
编辑 `system/yunsh-update-daemon.py` 中的 `REPO` 变量：
```python
REPO = "你的用户名/你的仓库名"
```

#### 改 Firstboot 安装源
编辑 `boot/yunsh-firstboot.sh` 中的镜像源配置：
```bash
REPLACE_URL="mirrors.your-mirror.com"
```

#### 改版本号
编辑 `build/yunsh-version.conf`：
```
VERSION=v1.0.0
BUILD=2026.07.10.01
```

### 贡献代码（Pull Request）

如果你想把自己的改进合并到主仓库：

1. **Fork 仓库**
   ```
   https://github.com/ljcccc999/yunsh-os → Fork
   ```

2. **Clone 你的 Fork**
   ```bash
   git clone git@github.com:你的用户名/yunsh-os.git
   cd yunsh-os
   git remote add upstream git@github.com:ljcccc999/yunsh-os.git
   ```

3. **创建分支，改代码，构建测试**
   ```bash
   git checkout -b feat/your-feature
   # ... 修改 QML / 脚本 / 配置
   bash scripts/build-image-from-rpi-os.sh  # 验证构建成功
   ```

4. **提交并推送**
   ```bash
   git add -A
   git commit -m "feat: 你的功能描述"
   git push origin feat/your-feature
   ```

5. **创建 Pull Request**
   在 GitHub 上：你的 fork → Pull Request → `ljcccc999/yunsh-os` 的 `main` 分支

6. **等待 Review**
   代码审查通过后会合并到主仓库。

### ⚠️ 注意事项

- **不要直接往主仓库 push**（只有仓库拥有者可以创建 Release）
- **构建产物不要提交**（`output/*.img*` 在 .gitignore 里）
- **原版 RPi OS 镜像不要提交**（`build/*.img` 在 .gitignore 里，约 2.8GB）
- **Git push 用 SSH**（HTTPS 可能被 GFW 阻断）
  ```bash
  # ~/.ssh/config
  Host github.com
      IdentityFile ~/.ssh/id_github
      AddKeysToAgent yes
  ```
- **QML 语法**：使用 Qt Quick 2.15 + Qt Quick Controls 2.15
- **WebEngine**：浏览器需要 `libqt6webengine-dev`，构建镜像已预装

### 常见问题

| 问题 | 解决 |
|------|------|
| `debugfs: command not found` | `brew install e2fsprogs` |
| 构建后镜像烧录不启动 | 确认 SD 卡 ≥ 16GB，SHA256 校验文件 |
| 激活向导不显示 | `sudo rm /etc/yunsh/.activated` 重启 |
| 截图后相册无图 | 检查 `~/Pictures/Screenshots/` 目录是否存在 |
| OTA 下载失败 | 确认 RPi 能访问 `api.github.com` |
| WebEngine 白屏 | 尝试加 `--disable-gpu` 启动参数 |
| GitHub push 被拒 | 用 SSH 方式，HTTPS 在国内不通 |

### 网络注意事项（中国 GFW）

| 域名 | 状态 |
|------|------|
| `github.com:443` | ❌ 阻断（push 走 SSH） |
| `api.github.com` | ✅ 可用（OTA 更新检查） |
| `release-assets.githubusercontent.com` | ✅ 可用（OTA 镜像下载） |
| `objects.githubusercontent.com` | ✅ 可用 |
| `mirrors.tuna.tsinghua.edu.cn` | ✅ 可用（firstboot 自动切换） |

首次启动自动检测 `sources.list` 中的 `deb.debian.org`，替换为清华镜像加速。

---

## 📝 License

**Tim (LiuJiacheng)**

**License**: © 2024 YUNSH Technology
