<p align="center">
  <img src="logo/logo-256.png" width="128" alt="YUNSH Logo" />
</p>

<p align="center">
  <a href="README.md">English</a> | <strong>中文</strong>
</p>

# YUNSH OS

<p align="center">
  面向 Raspberry Pi 5 与透明 AR 显示的互联空间桌面。
</p>

<p align="center">
  <a href="https://github.com/ljcccc999/yunsh-os/releases">下载最新版本</a>
  ·
  <a href="docs/YUNSH-OS-操作指南.md">使用指南</a>
  ·
  <a href="docs/ECOSYSTEM-ROADMAP.md">生态路线图</a>
</p>

YUNSH OS 是 YUNSH 生态的系统引擎。它把持续存在的系统世界、面向光学显示的桌面、系统级 Orbit Agent、设备互联服务和 Bluetooth-connected motion tracking 集中在一个便携的 Raspberry Pi 5 环境中。

当前本地发布线为 **v3.1.6**，包含圆形液态玻璃 Orbit 标识、岛内直接工具批准、语音波形反馈、可中断窗口转场、可移动 Orbit 与空间键盘，以及在应用窗口打开时自动隐退的桌面图标栏；所有界面共同使用系统级明亮液态玻璃视觉语言。

## 体验

### 空间工作区

- 默认输出一张完整桌面画面，由当前眼镜控制器同步显示到左右眼；同一输出也适用于普通显示器。
- 为未来独立左右眼控制器保留可选的高级 SBS 兼容模式。
- 为未来 IPD、水平融合、视场角、裁切和左右眼顺序校准提供设备端基础。
- 浮动应用窗口支持移动、缩放、最小化、关闭和全屏。
- 提供正前、左斜、右斜和远处四种直接 3DoF 空间布局。
- 窗口支持固定与跟随模式，实现视角相对显示。
- 类似 iOS 的上滑 App Switcher 将最小化应用保留为可点击后台卡片，并提供独立关闭操作。
- 支持 SpaceCapsule 工作区导出与恢复，以及通过本地网络完成加密的 YUNSH Drop 发现、发送和接收确认。
- YUNSH Link 可导入 `.yunshspace` 文件，并通过 iOS 系统分享面板继续转发到微信、文件、隔空投送或其他应用。
- YUNSH Flow 支持用户明确选择的照片/文件传输，以及 iPhone 与 YUNSH OS 之间显式发送或接收剪贴板内容。取回的文件可使用 iOS 分享面板继续发送到隔空投送、微信、文件或其他应用。
- 30Hz 头部姿态采样，支持可调平滑、yaw 跨界处理、roll 补偿和一键回正。
- 无 Dock 的 Home 工作区采用圆形液态玻璃应用图标、4–5–4 蜂窝布局、每页自动 13 个应用、任务切换器，以及可移动的玻璃虚拟键盘。键盘可直立或以桌面角度倾斜，并支持固定或跟随视线。
- 应用窗口打开后，图标自动隐退。点击露出的桌面可切换临时图标栏；恢复后 30 秒内没有打开应用或切换图标页，图标栏会再次隐藏。打开第二个应用也会立即隐藏图标。YUNSH 系统菜单提供持久显示/隐藏选项，手动隐藏不会被桌面点击取消。应用玻璃材质略微加厚，以提高光学显示可读性。
- 激活时可选 Comfort DNA，提供稳定、平衡和灵敏三种本地舒适预设。
- 支持专注模式、减少动效、减少透明度和增强对比度。
- 激活、应用、菜单、任务切换、键盘、对话框、浏览器、终端和恢复界面均使用统一的明亮液态玻璃语言。
- 干净的光学显示启动路径将内核和 systemd 诊断保留在 journal 与串口控制台，不会在 YUNSH 启动画面和桌面后方的 tty1 绘制命令输出。
- 在光学黑色透明画布上使用 AR 可见的白色液态玻璃表面。白色玻璃上的深色文字可提供更强对比；光学黑色仍用于透明画布、遮罩、校准和媒体内容。

当前 Shell 为双眼使用同一舒适焦平面。真正的应用级立体内容需要未来的独立左右眼渲染路径，当前 Shell 合成器不宣称已具备该能力。空间布局是视角相对的：用户转头时，桌面布局会保持。真实房间锚定需要未来的 6DoF 视觉追踪硬件，当前功能不代表已经实现。

### 持续存在的系统世界

YUNSH META Universe 是 Shell 直接拥有的世界层，不是普通应用窗口。全局菜单栏中央的常驻入口可直接打开世界基础层，而应用仍是这个持续世界中的工具。当前版本建立了系统入口、标识、空间与连续性表面，不宣称完整在线元宇宙平台或 6DoF 房间锚定已经完成。

### Orbit

Orbit 是系统级 Agent 运行时，每次开机自动启动，但不会成为桌面启动依赖。用户依次选择 API 提供商、模型并输入自己的 API Key。支持 DeepSeek、Kimi 和自定义 OpenAI 兼容端点。凭据使用设备本地密钥加密，本机 API 永远不会返回完整 Key。

Orbit 使用“规划—执行—观察—验证”循环处理多步任务。它的面板可以移动，同时始终保留全局系统入口；开始文字输入时会自动清理空间键盘的输入平面。Orbit 可以维护明确任务计划、打开和管理系统表面、进入世界层、检查实时 Shell 状态、截图并 OCR、控制录屏、操作文件、保存已批准记忆、执行命令，并在回复前验证结果。Low/Medium/High 推理档位与 Orbit iPhone 输入器一致，同时保留 DeepSeek 思考模式。本地运行时 API 只监听设备回环地址。

Orbit 设置中保留各项能力开关；敏感工具首次使用时提供“仅本次允许”“始终允许”或“拒绝”。电源、恢复出厂、破坏性 Shell 命令和类似高风险操作不能永久预先批准。重启、关机和恢复出厂还必须通过 Shell 的两阶段确认。

Orbit 默认提供甜美女声，也可选择男声。桌面可用后，语音组件在后台准备。只有检测到 USB 或蓝牙麦克风时才启用语音识别；当前眼镜硬件不被描述为内置麦克风。

独立 Orbit iPhone App 提供与眼镜中一致的对话和配置界面。YUNSH Link 完成配对后，Orbit 通过本地 Wi-Fi 或 iPhone 热点上的认证 TLS 桥连接设备运行时。对话、工具批准、提供商/模型选择和 API Key 设置都面向眼镜中同一个 Orbit 实例；iPhone App 不保存 API Key。

### 内置应用

- 基于 Qt WebEngine 的网页浏览器。
- 持久 PTY 终端。
- 全屏与区域截图、带常驻红色指示的录屏、上下文预览，以及照片/视频存储。
- SpaceCapsule 工作区管理器。
- iPhone Screen Relay 作为可移动、缩放和固定的空间窗口；它使用用户明确启动的 ReplayKit 广播，并通过加密本地 Wi-Fi 传输。
- 设置、系统信息、更新中心、网络和蓝牙管理。
- 通过 YUNSH Wayland 会话中的 Waydroid 提供集成 Android 应用环境；后台准备永远不会阻塞桌面或激活。
- Android 准备失败或状态过期时会显示明确重试操作，不会让界面永久停留在准备中。
- 内置经过验证的 F-Droid Android 应用目录，并支持通过 `yunsh-android install-apk` 侧载 APK。

### 设备服务

- 多语言“你好”欢迎语会持续循环，直到用户选择继续；随后进入触控优先的激活流程，分别设置本地 YUNSH 账户密码和设备解锁密码。YUNSH 账户密码以 PBKDF2-SHA256 哈希保存，修改其中一个凭据不会改变另一个。
- 默认使用 Smart Wake：自动熄屏会让 AR 表面变黑，并可立即恢复。用户主动选择“锁定”后，必须输入设备密码才能返回桌面；Orbit 和 YUNSH Link 都不能绕过本机检查。
- 设置中只能验证和修改 Linux 用户 `yunsh` 的设备解锁密码，本地 YUNSH 账户凭据保持不变。
- 眼镜与 iPhone 使用分开的可跳过配对页面，并显示进度。
- 手机使用不区分大小写的一次性配对密钥，不需要二维码或摄像头。
- Comfort DNA 设置可以跳过。
- Orbit 提供商、模型、API Key 与声音设置可以跳过。
- Wi-Fi 与蓝牙管理。
- OTA 更新服务和恢复出厂流程。
- 电源、输入、启动画面、截图、录屏、锁定和破坏性操作确认服务。
- 可通过 Bluetooth-connected motion controller 或兼容姿态源提供可选 3DoF 输入。

### YUNSH Link 连接模式

YUNSH Link 是 YUNSH 显示设备和 YUNSH OS 的伴侣应用。它根据当前体验选择两种互斥蓝牙连接模式之一。

YUNSH Link 完成手机配对后，独立 Orbit App 可以复用该设备绑定配对，通过加密本地链路发现系统。操作仍由 YUNSH OS 按与眼镜界面相同的权限和破坏性操作确认规则执行。

| 模式 | iPhone 连接 | 系统行为 |
| --- | --- | --- |
| **Phone Mode** | 直连 `YUNSH V1 (Glasses)` | 读取运动和眼镜电量状态，并发送显示亮度控制。该模式用于直接使用眼镜；蓝牙传输控制与遥测，不传输显示视频。 |
| **YUNSH OS Mode** | 只连接广播名为 `YUNSH V1` 的 Raspberry Pi | Raspberry Pi 连接眼镜，转发眼镜遥测与亮度控制，报告主机电量，并通过自己的网络连接接收伴侣应用发起的更新请求。 |

同一时间只能启用一个模式。YUNSH OS Mode 下，iPhone 不会同时直连眼镜；Raspberry Pi 是唯一连接与遥测中心。加密 BLE 特征还受到显示器上短期、单次使用的 YUNSH 配对密钥保护，密钥输入不区分大小写。

Screen Relay 使用 Apple 公共 ReplayKit 广播界面，始终需要 iPhone 用户明确确认。视频帧通过加密本地 Wi-Fi 或 iPhone 热点传输；蓝牙仍只负责配对、命令和遥测。YUNSH Link 不能静默录制 iOS，也不能把无关 iOS 应用拆成独立窗口。

YUNSH Flow 遵守同一传输边界：内容通过已配对的本地 TLS 网络连接传输，蓝牙负责发现和小型控制。外出时，Raspberry Pi 或未来计算模块可重连已保存的 iPhone 个人热点；iOS 仍要求用户手动开启热点。剪贴板访问只能由明确按钮发起，不会静默轮询。

## 架构

```text
双目 AR 显示控制器
    │ HDMI · 一张完整画面镜像到左右眼显示
Raspberry Pi 5
    ├── YUNSH OS Shell · 持续存在的 YUNSH META Universe 世界层
    ├── Orbit 系统 Agent · 提供商/模型配置 · 本地工具
    ├── Qt Quick 工作区 · 可选未来 SBS 合成器
    ├── 共享焦平面的应用窗口
    ├── 系统服务 · 网络 · 蓝牙 · 更新 · 电源
    ├── DRM/KMS + V3D Mesa 图形 · Wayland 合成应用
    ├── Wayland 合成的 Waydroid 应用环境
    └── 可选蓝牙运动控制器 → 头部追踪服务
```

用户界面在本机读取头部追踪服务。兼容姿态源将 yaw、pitch 和 roll 数据发布到追踪桥，使真实硬件与模拟输入共享同一 UI 路径。工作区把这些输入应用到固定窗口及其空间布局。

## 要求

| 组件 | 要求 |
| --- | --- |
| 计算机 | Raspberry Pi 5 |
| 显示 | 当前将一张完整画面镜像到左右眼的 HDMI 控制器，或普通显示器 |
| 存储 | 推荐 16GB 或更大的 A2 microSD 卡 |
| 输入 | 触控/凝视兼容指针、YUNSH Link 或鼠标；激活和回正不需要物理键盘 |
| 电源 | 适合 Raspberry Pi 5 的稳定 USB-C 电源 |
| 可选追踪 | Bluetooth-connected motion controller |

## 安装

1. 从 [Releases](https://github.com/ljcccc999/yunsh-os/releases) 下载最新 `.img.xz` 镜像和对应 SHA-256 文件。
2. 验证镜像校验值。
3. 使用 Raspberry Pi Imager、balenaEtcher 或其他兼容工具将镜像写入 microSD 卡。
4. 将卡插入 Raspberry Pi 5，连接显示与输入设备后开机。

### 验证下载

```bash
shasum -a 256 YUNSH-OS-<version>.img.xz
```

将结果与 Release 中同名 `.sha256` 资产进行比较。

## 首次启动

首次设置会在任何软件包事务开始前创建固定 Linux 服务账户 `yunsh`，下载所需桌面与媒体软件包，包括 Raspberry Pi 5 DRM/KMS、EGL、OpenGL、Vulkan、FFmpeg 和 OCR 运行时，然后重启一次进入激活。首次开机前请连接以太网。图形桌面需要 Pi 5 DRM/KMS 卡，并以 Weston 的 Pixman 渲染器作为主要 Wayland 路径；若该路径无法启动，服务会明确报告错误，而不会静默切换到旧 framebuffer 表面。

激活从多语言“你好”开始，然后依次引导语言、Wi-Fi、可选眼镜与 YUNSH Link 配对、本地账户、可选 Orbit 提供商/模型/Key/声音设置和可选 Comfort DNA。完成或跳过激活后会创建持久标记，后续启动直接进入桌面。

Pi 端 YUNSH Link BLE 服务广播独立 OS 服务，并在设置期间保持手机配对可用。iPhone 仍必须完成用户批准的六位数配对流程；Pi 端成功广播本身不代表完整 iPhone 会话已经通过。

恢复出厂会清除用户数据、已保存 Wi-Fi、蓝牙配对和激活标记，保留 YUNSH OS、已安装桌面依赖和当前系统版本，下次启动重新进入激活。

## 运动追踪

YUNSH OS 支持可选的 Bluetooth-connected motion tracking。头部追踪桥为兼容运动源和内置开发模拟器提供统一接口。追踪可用后，每个浮动窗口都可以从标题栏直接选择正前、左斜、右斜或远处布局。用户可通过常驻回正按钮或 iPhone 上的 YUNSH Link 回正；开发环境仍保留键盘快捷键。

```text
蓝牙运动控制器 → 头部追踪桥 → YUNSH OS 工作区
```

## 仓库结构

```text
boot/       首次运行配置与启动资产
docs/       产品和操作文档
logo/       YUNSH 品牌资产
scripts/    镜像构建、启动注入和烧录工具
system/     运行时服务、辅助程序和系统守护进程
ui/         Qt Quick 用户界面与可复用玻璃组件
```

## 构建

镜像构建面向 macOS，使用 `mtools` 操作 FAT 启动分区，使用 `e2fsprogs`/`debugfs` 注入根文件系统。主要构建入口为：

```bash
scripts/build-no-hdiutil.sh
```

构建前请阅读脚本和基础镜像要求。生成的镜像和大型构建产物不会进入版本控制。

主要镜像构建把显示时序交给所连接控制器的 EDID，不强制旧式 1920×1080 内核模式。YUNSH OS 需要 DRM/KMS 卡，以 Weston/Wayland 和软件 Pixman 渲染器运行，不会静默降级到 Qt `linuxfb`。YUNSH OS 默认输出一张完整画面，由当前眼镜控制器把同一画面显示到左右屏。

## 项目状态

YUNSH OS 是面向 YUNSH 空间计算硬件的活跃原型。v3.1.6 发布线已通过 QML、Python、Shell、镜像结构、分区、启动配置、ext4、嵌入文件和 systemd 链接静态检查。一次干净的 ARM64 generic-virt 测试完成了 firstboot，以 MB 显示下载进度，跨过此前约 42% 的网络接管点，验证 SSH 和桌面前置条件，写入完成标记并自动重启。重启后，SSH、`yunsh-os.service` 和启动后健康守护均可访问。通用 virt 虚拟机不提供 Raspberry Pi 5 DRM/fb scanout，因此这项测试不代表 Pi 5 显示、鼠标、蓝牙、Android 或光学显示硬件已经通过。

## 许可证

Copyright © 2024–2026 YUNSH。保留所有权利。
