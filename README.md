# YUNSH OS

<p align="center">
  <img src="logo/logo-256.png" width="128" alt="YUNSH logo" />
</p>

<p align="center">
  A spatial operating environment for Raspberry Pi 5 and transparent AR displays.
</p>

<p align="center">
  <a href="https://github.com/ljcccc999/yunsh-os/releases">Download the latest release</a>
  ·
  <a href="docs/YUNSH-OS-操作指南.md">User guide</a>
</p>

YUNSH OS is the connection layer of the YUNSH ecosystem. It combines a dark, optical-display-ready canvas with glass surfaces, floating applications, device services, and a foundation for spatial interaction.

## Experience

### Spatial workspace

- Floating application windows with move, resize, minimize, close, and full-screen controls.
- Window pin and follow modes for 3DoF-ready display behavior.
- Home workspace, task switcher, Control Center, and a glass virtual keyboard.
- Black background designed for transparent optical displays; white glass surfaces preserve legibility.

### Built-in applications

- Web browser powered by Qt WebEngine.
- Persistent PTY terminal.
- Screenshot capture with in-context preview and photo library.
- Settings, system information, update center, network, and Bluetooth management.
- Android application support through Waydroid and the YUNSH application launcher.

### Device services

- Guided activation and first-run setup.
- Wi-Fi and Bluetooth management.
- OTA update service and factory-reset workflow.
- Power, input, splash-screen, and screenshot services.
- Optional 3DoF input through a Bluetooth-connected motion controller or compatible orientation source.

## Architecture

```text
AR Display
    │ HDMI
Raspberry Pi 5
    ├── YUNSH OS shell · Qt Quick workspace · application windows
    ├── System services · network · Bluetooth · updates · power
    ├── Waydroid application environment
    └── Optional Bluetooth motion controller → head-tracking service
```

The user interface reads the head-tracking service locally. Compatible orientation sources publish yaw, pitch, and roll data to the tracking bridge, allowing hardware and simulated input to share the same UI path.

## Requirements

| Component | Requirement |
| --- | --- |
| Computer | Raspberry Pi 5 |
| Display | 1080p HDMI AR display or monitor |
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

The initial setup prepares the runtime environment and presents the activation flow. Keep the device connected to the network during this step. After setup completes, YUNSH OS opens the desktop workspace.

## Motion tracking

YUNSH OS supports optional Bluetooth-connected motion tracking for spatial interaction. The head-tracking bridge provides a consistent interface for compatible motion sources and for the built-in development simulator.

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

## Project status

YUNSH OS is an active prototype for YUNSH spatial computing hardware. Hardware-dependent capabilities—including optical display behavior, Android compatibility, IMU tracking, and OTA delivery—should be validated on the intended Raspberry Pi 5 configuration.

## License

Copyright © 2024–2026 YUNSH. All rights reserved.
