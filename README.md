# YUNSH OS

<p align="center">
  <img src="logo/logo-256.png" width="128" alt="YUNSH logo" />
</p>

<p align="center">
  A connected spatial desktop for Raspberry Pi 5 and transparent AR displays.
</p>

<p align="center">
  <a href="https://github.com/ljcccc999/yunsh-os/releases">Download the latest release</a>
  ·
  <a href="docs/YUNSH-OS-操作指南.md">User guide</a>
</p>

YUNSH OS is the connection layer of the YUNSH ecosystem. It combines an optical-display-ready desktop, floating applications, connected-device services, and Bluetooth-connected motion tracking in a single Raspberry Pi 5 environment.

## Experience

### Spatial workspace

- Binocular side-by-side compositor with frame-locked left and right views.
- EDID-driven output for a dual-eye display controller or a conventional monitor.
- On-device calibration for IPD, horizontal fusion, field of view, crop, and eye order.
- Floating application windows with move, resize, minimize, close, and full-screen controls.
- Direct spatial window layouts for 3DoF viewing: front, left angle, right angle, and distance presets.
- Window pin and follow modes for view-relative display behavior.
- 30 Hz head-pose sampling with adjustable smoothing, yaw wrap handling, roll compensation, and one-action recentering.
- Home workspace, task switcher, Control Center, and a glass virtual keyboard.
- Focus mode, reduced motion, reduced transparency, and increased contrast.
- Black background designed for transparent optical displays; white glass surfaces preserve legibility.

The shell uses one comfortable shared focal plane for both eyes. True stereo application content requires a future per-eye rendering path and is not claimed by the current shell compositor. Spatial layouts are view-relative: head rotation preserves the desktop arrangement as the user looks around. Real-world room anchoring requires future 6DoF visual tracking hardware and is not represented as a current feature.

### Built-in applications

- Web browser powered by Qt WebEngine.
- Persistent PTY terminal.
- Screenshot capture with in-context preview and photo library.
- Settings, system information, update center, network, and Bluetooth management.
- Integrated Android application environment through Waydroid on the YUNSH Wayland session; its background preparation never blocks the desktop or activation flow.
- Built-in Android app catalogue with a verified F-Droid fallback, plus APK side-loading through `yunsh-android install-apk`.

### Device services

- Guided activation and first-run setup.
- Wi-Fi and Bluetooth management.
- OTA update service and factory-reset workflow.
- Power, input, splash-screen, and screenshot services.
- Optional 3DoF input through a Bluetooth-connected motion controller or compatible orientation source.

### YUNSH Link connection modes

YUNSH Link is the companion application for the YUNSH display and YUNSH OS. It uses one of two mutually exclusive Bluetooth connection modes, selected for the active experience.

| Mode | iPhone connection | System behavior |
| --- | --- | --- |
| **Phone Mode** | Connects directly to `YUNSH V1 (Glasses)` | Reads motion and glasses battery status, and sends display-brightness controls. This mode is for direct glasses use; Bluetooth carries control and telemetry, not display video. |
| **YUNSH OS Mode** | Connects only to the Raspberry Pi advertising as `YUNSH V1` | The Raspberry Pi connects to the glasses, relays glasses telemetry and brightness control, reports host power, and receives companion-initiated update requests over its own network connection. |

Only one mode is active at a time. In YUNSH OS Mode, the iPhone does not also connect directly to the glasses; the Raspberry Pi is the single connection and telemetry hub.

## Architecture

```text
Binocular AR Display
    │ HDMI · side-by-side frame
Raspberry Pi 5
    ├── YUNSH OS shell · Qt Quick workspace · binocular compositor
    ├── Shared focal-plane application windows
    ├── System services · network · Bluetooth · updates · power
    ├── DRM/KMS + V3D Mesa graphics · Wayland-composited applications
    ├── Wayland-composited Waydroid application environment
    └── Optional Bluetooth motion controller → head-tracking service
```

The user interface reads the head-tracking service locally. Compatible orientation sources publish yaw, pitch, and roll data to the tracking bridge, allowing hardware and simulated input to share the same UI path. The workspace applies this input to pinned windows and their selected spatial layouts.

## Requirements

| Component | Requirement |
| --- | --- |
| Computer | Raspberry Pi 5 |
| Display | HDMI binocular AR display controller with an EDID-advertised SBS mode, or a conventional monitor for mono development |
| Storage | 16 GB or larger A2 microSD card recommended |
| Input | USB keyboard and mouse for setup and desktop control |
| Power | Stable USB-C power supply suitable for Raspberry Pi 5 |
| Optional tracking | Bluetooth-connected motion controller |

## Install

1. Download the latest `.img.xz` image and its SHA-256 asset from [Releases](https://github.com/ljcccc999/yunsh-os/releases).
2. Verify the image checksum.
3. Flash the image to a microSD card using Raspberry Pi Imager, balenaEtcher, or another compatible imaging tool.
4. Insert the card into a Raspberry Pi 5, connect the display and input devices, then power on.

### Verify the download

```bash
shasum -a 256 YUNSH-OS-<version>.img.xz
```

Compare the result with the matching `.sha256` asset published with the release.

## First boot

The initial setup downloads the required desktop packages, including the Raspberry Pi 5 DRM/KMS, EGL, OpenGL, and Vulkan runtime, and then reboots once into the activation flow. Connect Ethernet before the first power-on and keep the device online until setup finishes. A temporary network failure retries automatically without marking the setup complete. Completing or skipping activation creates a persistent activation marker, so later boots open the desktop directly.

Factory reset clears user data, saved Wi-Fi networks, Bluetooth pairings, and the activation marker. It preserves YUNSH OS, installed desktop dependencies, and the current system version, then returns to activation on the next boot.

## Motion tracking

YUNSH OS supports optional Bluetooth-connected motion tracking for spatial interaction. The head-tracking bridge provides a consistent interface for compatible motion sources and for the built-in development simulator. After tracking is available, each floating window can be placed directly in a front, left-angle, right-angle, or distance layout from its title bar. The current direction can be recentered from Control Center or with `Ctrl+Shift+R`.

```text
Bluetooth motion controller → head-tracking bridge → YUNSH OS workspace
```

## Repository layout

```text
boot/       First-run configuration and boot assets
docs/       Product and operating documentation
logo/       YUNSH brand assets
scripts/    Image build, boot injection, and flashing tools
system/     Runtime services, helpers, and system daemons
ui/         Qt Quick user interface and reusable glass components
```

## Build

The image build is designed for macOS and uses `mtools` for the FAT boot partition and `e2fsprogs`/`debugfs` for root-file-system injection. The primary build entry point is:

```bash
scripts/build-no-hdiutil.sh
```

Review the script and its input image requirements before building. Generated images and large build artifacts are intentionally excluded from version control.

The primary image build leaves display timing to DRM/KMS and the connected controller's EDID. It does not force a legacy 1920×1080 kernel mode, allowing a binocular controller to expose its native side-by-side resolution.

## Project status

YUNSH OS is an active prototype for YUNSH spatial computing hardware. Hardware-dependent capabilities—including optical display behavior, Android compatibility, IMU tracking, and OTA delivery—should be validated on the intended Raspberry Pi 5 configuration.

## License

Copyright © 2024–2026 YUNSH. All rights reserved.
