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

## 🔧 快速开始

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

## 🏗 开发者

### 构建环境 (macOS)

```bash
# 依赖
brew install e2fsprogs xz
pip3 install Pillow

# 下载 RPi OS Lite arm64 到 build/ 目录
# 构建
bash scripts/build-image-from-rpi-os.sh
```

### 项目结构

```
yunsh-os/
├── boot/         启动配置 + firstboot 脚本
├── scripts/      构建 & 烧录脚本
├── system/       系统 daemon + 服务文件
├── ui/           29 QML 文件 + 11 SVG 图标
├── logo/         品牌 logo 多尺寸
├── output/       构建输出 (.img.xz ~570MB)
└── README.md
```

### 网络 (中国 GFW)

- `github.com:443` ❌ 阻断 → **用 SSH push**
- `api.github.com` ✅ 可通（OTA 检查用）
- `release-assets.githubusercontent.com` ✅ 可通（OTA 下载用）
- firstboot 自动用 **清华镜像** 加速

---

## 📝 License

© 2024 YUNSH Technology · Developer: Tim (LiuJiacheng)
