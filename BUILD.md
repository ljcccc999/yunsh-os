# YUNSH OS 构建指南

开发者文档：如何从源码构建 YUNSH OS 镜像。

## 目录结构

```
yunsh-os/
├── boot/               # 启动配置 (config.txt, kms-config.json)
├── scripts/            # 构建 & 刷写脚本
│   ├── build-image-from-rpi-os.sh   # 从 RPi OS 构建镜像
│   ├── yunsh-boot-activate.sh       # 首启动激活脚本
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

## 构建镜像

### 前置条件

- macOS 或 Linux
- `e2fsprogs`（macOS: `brew install e2fsprogs`）
- `xz`（macOS: `brew install xz`）
- Raspberry Pi OS Lite (Debian 13 Trixie) arm64 镜像

### 构建

```bash
# 配置
export RPIZ_IMAGE="raspios-lite.img"
export OUTPUT_IMAGE="output/YUNSH-OS-v1.0.0.img"

# 构建
./scripts/build-image-from-rpi-os.sh
```

### 构建流程

1. 下载 Raspberry Pi OS Lite (arm64)
2. 注入 Qt6 运行时 + QML 模块
3. 注入 YUNSH 激活脚本 + UI 文件
4. 配置首启动 systemd 服务
5. 压缩为 `.img.xz` 输出

### 烧录到 SD 卡

```bash
xz -d -k output/YUNSH-OS-v1.0.0.img.xz
diskutil unmountDisk /dev/disk2
sudo dd if=output/YUNSH-OS-v1.0.0.img of=/dev/rdisk2 bs=1m status=progress
```

## 系统架构

### 首启动流程

```
开机 → yunsh-boot-activate 脚本（检查 /etc/yunsh/.activated）
  → 未激活 → 启动 Qt6 QML ActivationScreen（内置镜像）
    → 欢迎 → 语言 → Wi-Fi → 激活码（可选）
    → 点击"开始初始化" → yunsh-firstboot.sh 下载剩余组件
    → 安装完成 → 重启 → 进入系统
  → 已激活 → 跳过，直接启动主 YUNSH OS
```

### OTA 更新流程

```
yunsh-update-daemon.py（每 6 小时检查）
  → GET GitHub Releases API
  → Stable：GET /repos/ljcccc999/yunsh-os/releases/latest（非 prerelease）
  → Beta：GET /repos/ljcccc999/yunsh-os/releases?per_page=5（最新全部）
  → 比较版本号
  → 检测到大版本且 allow_major_update=False → 跳过
  → 有更新 → 通知用户

yunsh-updater.py（用户确认更新后）
  → 下载 .img.xz
  → 解压
  → 写入备用分区（mmcblk0p2 ↔ mmcblk0p3）
  → 在目标分区写入 .installed + .activated 标记
  → 切换启动分区
  → 重启
```

## 发布新版本

推荐直接 GitHub 网页操作：

1. 打开 https://github.com/ljcccc999/yunsh-os/releases/new
2. 输入版本标签（如 `v1.1.0`）
3. 编写更新说明
4. 上传 `.img.xz` 文件
5. 测试版勾选 **Set as a pre-release**
6. 点击 Publish release

### 版本规范

- **正式版：** `v1.0.0` → `v1.1.0` → `v2.0.0`
- **测试版：** `v1.1.0-beta` → `v1.1.0-beta2`
- 大版本：主版本号变化（v1.x → v2.0）
- 小版本：次版本号变化（v1.0 → v1.1）
