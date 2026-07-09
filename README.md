# YUNSH OS v1.0 - 树莓派 AR 眼镜操作系统

基于 Buildroot 从零构建的独立 Linux 系统，为 YUNSH V1 AR 眼镜定制。

## 架构概览

```
┌──────────────────────────────────────┐
│         YUNSH OS v1.0                │
├──────────────────────────────────────┤
│  应用层: 设置 · 应用宝 · 文件管理     │
├──────────────────────────────────────┤
│  UI框架: Qt6/QML (毛玻璃设计)         │
├──────────────────────────────────────┤
│  Android: Waydroid + 应用宝           │
├──────────────────────────────────────┤
│  合成器: DRM+GLES (纯黑=透明)         │
├──────────────────────────────────────┤
│  系统: Linux 6.6 LTS + Buildroot      │
├──────────────────────────────────────┤
│  硬件: 树莓派 4B/5 + 1080p 屏幕       │
└──────────────────────────────────────┘
```

## 目录结构

```
yunsh-os/
├── buildroot/configs/   # Buildroot defconfig
├── kernel/              # Linux 内核配置
├── boot/                # 启动配置 (config.txt, cmdline.txt)
├── compositor/          # C++ 显示合成器 (DRM/EGL/GLES)
├── ui/                  # Qt6/QML UI (毛玻璃设计)
├── android/             # Waydroid 容器配置
├── system/              # 系统服务 (inputd, powerd)
├── scripts/             # 构建 & 刷写脚本
├── logo/                # YUNSH Logo 多尺寸
└── icons/               # SVG 图标集
```

## 核心特性

- **纯黑透明背景**: 背景 #000000, AR 眼镜中→透明
- **毛玻璃 UI**: 所有面板使用 Glassmorphism (blur:20px, opacity:0.35)
- **鼠标键盘输入**: 即插即用 USB 设备
- **应用宝集成**: 通过 Waydroid 运行 Android 应用
- **完整设置页面**: 网络 · 显示 · 声音 · 应用管理 · 系统更新
- **关于本机页面**: 设备信息 + YUNSH Logo

## 构建方法

### 方法一: 在 Linux/Mac 上构建

```bash
# 1. 处理 Logo
./scripts/process-logo.sh

# 2. 一键构建
./scripts/build-yunsh-os.sh
```

构建耗时: 首次约 30-60 分钟

### 方法二: 在 Mac 上直接刷写预构建镜像

```bash
# 1. 插入 SD 卡
# 2. 查看设备名
diskutil list

# 3. 运行刷写脚本
./scripts/flash-mac.sh
```

## 硬件要求

- **主板**: Raspberry Pi 4B (2GB/4GB/8GB) 或 Raspberry Pi 5
- **显示屏**: 1080p Micro-OLED 单目 AR 眼镜 (HDMI 输入)
- **输入**: USB 鼠标 + USB 键盘
- **存储**: 16GB+ SD 卡 (建议 Class 10 / A2)
- **电源**: 5V/3A USB-C

## 色彩规范

| 用途 | 颜色 |
|------|------|
| 主背景 | `#000000` (透明) |
| 面板 | `rgba(20,20,30,0.35) + blur(20px)` |
| 主文字 | `#FFFFFF` |
| 次要文字 | `#A0A0A0` |
| 强调色 | `#00D4FF` (青色) |
| 成功 | `#00E676` (绿色) |
| 警告 | `#FFB300` (橙色) |
| 错误 | `#FF1744` (红色) |

## License

© 2024 YUNSH Technology
