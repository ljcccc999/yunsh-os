# YUNSH OS v1.0 — AR 眼镜操作系统

面向 YUNSH V1 AR 眼镜的定制系统，基于 **Raspberry Pi OS Lite (Debian 13 Trixie)**。
全 visionOS 毛玻璃 UI + macOS 浮动窗口，AR 透明黑底设计。

<p align="center">
  <img src="logo/logo-256.png" width="128" alt="YUNSH Logo"/>
</p>

> ⬇️ **[下载最新镜像](https://github.com/ljcccc999/yunsh-os/releases)**

```
┌───────────────────────────────────────┐
│        YUNSH OS v1.0 — visionOS       │
├───────────────────────────────────────┤
│  ⚛ 主界面: 动态翻页 + 毛玻璃图标      │
│  📱 Waydroid 安卓兼容 + 玻璃窗口框架  │
│  🌐 WebEngine 浏览器 (GFW-safe)       │
│  📷 相册 + 截图系统                   │
│  🖥 PTY 终端 (持久化会话)             │
│  📡 OTA 双通道更新 (Stable/Beta)      │
│  🎨 全系统 visionOS 毛玻璃设计        │
└───────────────────────────────────────┘
```

---

## ✨ 特性

### 🪟 macOS 风格浮动窗口
- 每个 App 打开为独立圆角毛玻璃窗口
- 左上角三颗按钮：关闭 🔴 最小化 🟡 全屏 🟢
- 拖拽移动 + 缩放（全 5 边缘手柄）
- 重叠排列，多窗口共存于纯黑背景
- 设置 · 浏览器 · 终端 · 相册 · 系统更新 · 系统信息 · 关于 · Wi-Fi · 蓝牙 · 元宇宙 · 更新历史

### 📌 窗口钉选模式（3DoF 头部追踪）
- 每个窗口右上角图钉按钮切换 **悬停**/**视线跟随** 模式
- 📌 **悬停**：窗口固定在 AR 空间，转头时屏幕位置反向补偿
- 👀 **跟随**：窗口轻柔跟随头部微动，始终在视野中央
- `yunsh-headtracking` 守护进程：UDP :8595 接收 IMU → HTTP :8592 供 QML 轮询
- 硬件未就绪时可用 `yunsh-headtracking-sim` 键盘/鼠标模拟

### 🖼️ visionOS 毛玻璃 UI
- 纯黑 AR 透明背景
- 全系统 frosted glass 毛玻璃面板 + 顶光 + 阴影
- iOS 式动态翻页主屏（超 8 个 App 自动新增页）
- App Switcher: 任务切换器，底部 Home 指示条触发
- 圆形毛玻璃图标 · 玻璃 orb 时钟 widget
- 系统级长按复制/粘贴菜单

### 📱 Waydroid 安卓兼容
- 预装应用宝（腾讯应用商店）
- Python HTTP daemon 启动 Android 应用
- Android 应用在浮动玻璃窗口框架中运行

### 🌐 内置浏览器
- Qt6 WebEngine（Chromium 内核）
- 前进/后退/刷新/加载进度
- 自动 HTTPS → HTTP fallback
- Bing 搜索 · `Ctrl+L` 聚焦地址栏

### 📷 相册 & 截图系统
- 多种截图方式: Print 键 / 状态栏图标 / 悬浮按钮 / `Ctrl+Shift+S` / 控制中心
- 自动读取 `~/Pictures/Screenshots/`
- 5 列毛玻璃缩略图网格 + 全屏预览

### 🖥 内置终端
- Python PTY 后端（:8591）
- 会话持久化（切界面不中断）
- 复制/粘贴支持

### 📡 OTA 双通道更新
- Stable / Beta 双通道 · 大版本开关
- GFW-safe: 走 `api.github.com` + `release-assets.githubusercontent.com`
- A/B 分区更新，失败可回退
- 更新界面显示发布说明 + 操作方式

### 📊 实时系统信息
- CPU / 内存 / 存储 / 内核从 /proc 动态读取
- 内存每 10 秒刷新，用色条实时显示压力
- 设备型号（Pi 4 / Pi 5）自动识别

---

## 📦 系统组件

### 7 个系统服务

| 服务 | 说明 |
|------|------|
| `yunsh-os` | UI 启动器（QML 主入口） |
| `yunsh-splash` | Apple 式两段 splash（atom → logo + 文字） |
| `yunsh-network` | Wi-Fi 扫描/连接管理 |
| `yunsh-bluetooth` | 蓝牙设备管理 |
| `yunsh-update` | OTA 更新守护（每 6h 检查） |
| `yunsh-headtracking` | 3DoF IMU 头追（UDP :8595 → HTTP :8592） |
| `yunsh-appd` | Waydroid 应用启动代理 |
| `yunsh-terminal` | PTY 终端后台 |

### QML 组件

主界面 · App Switcher · Home 指示条 · 激活向导 · 设置
浏览器 · 相册 · 终端 · 元宇宙 · 控制中心 · 状态栏
虚拟键盘 · 屏保 · 截图叠加 · 毛玻璃组件库

---

## 🚀 开始使用

### 硬件要求

| 项目 | 规格 |
|------|------|
| 主板 | Raspberry Pi 4B (2GB+) / Pi 5 |
| 显示 | 1080p HDMI（AR 眼镜 / 显示器） |
| 输入 | USB 鼠标 + 键盘 |
| 3DoF 追踪（可选） | 带 IMU (MPU6050 等) 的 MCU，通过 UDP :8595 发送 JSON 旋转数据 |
| 无硬件时 | `yunsh-headtracking-sim` 键盘/鼠标模拟器即可测试 |
| 存储 | 16GB+ SD 卡（建议 A2） |
| 电源 | 5V/3A USB-C |

### 烧录

**macOS**:
```bash
xzcat YUNSH-OS-v1.0.1.img.xz | sudo dd of=/dev/rdisk2 bs=1m status=progress
```

**Windows**:
1. 下载 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) 或 [balenaEtcher](https://etcher.balena.io/)
2. 先解压镜像（用 7-Zip 解压 `.xz` 文件得到 `.img`）
3. 打开烧录工具，选中 `.img` 文件，选中 SD 卡，点击烧录

验证 SHA256:
```bash
# macOS
shasum -a 256 YUNSH-OS-v1.0.1.img.xz

# Windows (PowerShell)
Get-FileHash YUNSH-OS-v1.0.1.img.xz -Algorithm SHA256
```

### 首次开机

1. 插卡通电 → 自动安装 Qt6 / Waydroid / 应用宝（需联网）
2. 自动重启 → 激活向导（选择语言 → 连接 Wi-Fi → 创建账户）
3. 进入 YUNSH 主界面 🎯

---

## 🎮 操作方式

### 鼠标操作

| 操作 | 功能 |
|------|------|
| 左键点击（图标） | 打开应用 |
| 左键点击（Home 指示条） | 打开 App Switcher（任务切换器） |
| 按住 Home 指示条向上拖拽 | 打开 App Switcher（>30px 触发） |
| 点击 App Switcher 卡片 | 切换至该应用 |
| 卡片 ✕ 按钮 | 关闭应用 |
| 点击空白区域 / Escape | 关闭 App Switcher / 返回桌面 |
| ← 返回胶囊 | 返回上级页面 |
| 长按文字 | 弹出复制/粘贴菜单 |
| 右键 | 粘贴（Terminal） |
| **拖拽标题栏** | 移动浮动窗口 |
| **点击窗口** | 将该窗口置顶 |
| **边缘拖拽**（左/右/下/角） | 缩放窗口 |
| 🔴🟡🟢 | 关闭/最小化/全屏 |
| **右上角图钉** 📌 | 切换悬停/视线跟随模式 |

### 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| **Escape** | 返回 / 关闭面板 |
| **Print** | 截取全屏 |
| **Ctrl + Shift + S** | 区域截图 |
| **Ctrl + Shift + C** | 打开/关闭控制中心 |
| **Ctrl + ↑** | 打开 App Switcher（任务切换器） |
| **Ctrl + L** | 浏览器地址栏聚焦 / 终端清屏 |
| **Ctrl + R** | 刷新浏览器页面 |

### App Switcher（任务切换器）

- **触发方式**: 点击 Home 指示条 / 上滑拖拽 / `Ctrl+↑`
- 横向滚动浏览打开的应用
- 点击卡片切换，✕ 关闭
- 关闭所有应用 → 自动回到主屏幕

### 控制中心

`Ctrl+Shift+C` 或状态栏 ☰ 图标打开
- Wi-Fi / 蓝牙开关
- 虚拟键盘 / 截图快捷按钮
- 亮度 / 音量滑块
- Wi-Fi / 蓝牙设置快捷入口

### 截图

五种方式触发：Print 键 / 状态栏截图图标 / 浮动截图按钮 / `Ctrl+Shift+S` / 控制中心

截图后右上角显示预览，自动保存到 `~/Pictures/Screenshots/`

### 恢复出厂设置

清除所有用户数据 + 已安装应用，保留系统版本和 OTA 配置。
重启后进入激活向导。

### 待机

2 分钟无操作 → 屏保，移动鼠标唤醒。

---

## 🛠 构建

**构建环境**: macOS（依赖 e2fsprogs 的 debugfs 操作 ext4 分区）+ Python3 Pillow（生成 splash 帧缓冲）

**构建逻辑**:
- 基于 RPi OS Lite (Debian Trixie arm64) 镜像
- 通过 debugfs 直接注入 ext4 分区，无需 Docker/虚拟机
- 注入内容: QML 组件库、SVG 图标、logo、系统脚本、systemd 服务、配置文件
- 配置 1080p KMS 显示、autologin、hostname
- 生成 Apple 两段式 splash（atom → logo+文字）
- 注入完成后合并 boot + root 分区

**产物**: `output/YUNSH-OS-v1.0.1.img.xz`（~570MB）

构建脚本: `scripts/build-image-from-rpi-os.sh`

注意: 构建产物和原版镜像在 .gitignore 中，不会提交到仓库。

---

## 📝 License

Developer：Tim（LiuJiacheng）

© 2024 YUNSH,Inc.
