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
  ·
  <a href="docs/ECOSYSTEM-ROADMAP.md">Ecosystem roadmap</a>
</p>

YUNSH OS is the system engine of the YUNSH ecosystem. It combines a persistent
system world, an optical-display-ready desktop, the system-level Orbit agent,
connected-device services, and Bluetooth-connected motion tracking in one
portable Raspberry Pi 5 environment.

The current local release line is **v3.1.3**, with a circular liquid-glass
Orbit identity, direct in-island tool approvals, voice speaking-wave feedback,
interruptible window transitions, a movable Orbit and spatial keyboard, and a
desktop icon shelf that recedes when an application window opens, all within a
system-wide bright liquid-glass material language.

## Experience

### Spatial workspace

- One complete desktop frame by default, synchronized to both eye displays by
  the current glasses controller; the same output works on a conventional monitor.
- Optional advanced side-by-side compatibility mode for a future independent-eye controller.
- On-device calibration foundation for future IPD, horizontal fusion, field of view, crop, and eye order controls.
- Floating application windows with move, resize, minimize, close, and full-screen controls.
- Direct spatial window layouts for 3DoF viewing: front, left angle, right angle, and distance presets.
- Window pin and follow modes for view-relative display behavior.
- An iOS-inspired swipe-up App Switcher keeps minimized apps as tappable
  background cards and provides an independent close control.
- SpaceCapsule export and restore, plus encrypted YUNSH Drop discovery, sender delivery, and receiver approval on the local network.
- YUNSH Link import for forwarding `.yunshspace` files through the iOS share sheet to WeChat, Files, AirDrop, or another installed app.
- YUNSH Flow for user-selected photo/file transfer and explicit clipboard send
  or receive between iPhone and YUNSH OS. Retrieved files use the iOS share
  sheet for AirDrop, WeChat, Files, or another app.
- 30 Hz head-pose sampling with adjustable smoothing, yaw wrap handling, roll compensation, and one-action recentering.
- A Dock-free Home workspace with circular liquid-glass application icons,
  visionOS-style 4–5–4 honeycomb placement, automatic 13-app pages, a task
  switcher, and a movable glass virtual keyboard with upright or desk-pitched
  presentation plus pinned or gaze-following behavior.
- Application icons recede automatically when a window opens. Selecting the
  exposed desktop toggles the temporary shelf; after restoration, 30 seconds
  without opening an app or changing icon pages hides it again. Opening any
  second app also hides it immediately. The YUNSH system menu offers a
  persistent show/hide control, and a manual hide choice is not cancelled by
  a desktop click. Application glass is slightly denser for optical-display
  legibility.
- Optional Comfort DNA onboarding with steady, balanced, and responsive local comfort profiles.
- Focus mode, reduced motion, reduced transparency, and increased contrast.
- One bright liquid-glass material language across visible system surfaces,
  including activation, applications, menus, task switching, keyboard,
  dialogs, browser and terminal chrome, and recovery UI.
- A clean optical-display startup path keeps kernel and systemd diagnostics in
  the journal and on the serial console instead of painting command output on
  tty1 behind the YUNSH splash and desktop.
- AR-visible white liquid-glass surfaces over an optical-black transparent
  canvas. Dark text is used on bright glass where it provides stronger
  contrast; optical black remains available for transparent canvas, dimming,
  calibration, and media content.

The shell uses one comfortable shared focal plane for both eyes. True stereo application content requires a future per-eye rendering path and is not claimed by the current shell compositor. Spatial layouts are view-relative: head rotation preserves the desktop arrangement as the user looks around. Real-world room anchoring requires future 6DoF visual tracking hardware and is not represented as a current feature.

### Persistent system world

YUNSH META Universe is a shell-owned world layer, not an application window.
The permanent center entry in the global menu bar opens the world foundation
directly, while applications remain tools inside the wider persistent-world
experience. The current release establishes the system entry, identity,
space, and continuity surfaces; it does not claim that the complete online
metaverse platform or 6DoF room anchoring is finished.

### Orbit

Orbit is the system-level agent runtime and starts automatically on every boot
without becoming a desktop-start dependency. Users select an API provider,
then a model, then enter their own API key. DeepSeek, Kimi, and a custom
OpenAI-compatible endpoint are supported. The credential is encrypted using a
device-local key and is never returned in full by the local API.

Orbit uses a plan–act–observe–verify loop for multi-step work. Its panel can be
moved without losing access to the global system entry, and it automatically
clears the spatial keyboard's input plane when text entry begins. It can maintain
an explicit task plan, open and manage system surfaces, enter the world layer,
inspect the live shell state, capture and OCR the display, control screen
recording, work with files, keep approved memory, execute commands, and verify
results before replying. A Low/Medium/High reasoning profile mirrors the Orbit
iPhone composer, while DeepSeek thinking mode remains available. The runtime API
listens on device loopback only.

Capability switches remain available in Orbit settings, while sensitive tools
request **Allow Once**, **Always Allow**, or **Deny** on first use. Power,
factory reset, destructive shell commands, and similar high-risk actions
cannot be permanently pre-approved. Restart, shutdown, and factory reset also
pass through the shell's two-stage confirmation before execution.

Orbit supports a default sweet female voice and an optional male voice. Voice
components prepare in the background after the desktop is available. Speech
recognition activates only when a USB or Bluetooth microphone is detected;
the current glasses hardware is not described as having an integrated
microphone.

The same Orbit conversation and configuration surface is available in a
standalone Orbit iPhone app. Pairing is established by YUNSH Link, then Orbit
reaches the on-device runtime through an authenticated TLS bridge on local
Wi-Fi or an iPhone hotspot. Chat, tool approvals, provider/model selection, and
API-key setup target the same Orbit instance shown in the glasses; the iPhone
app does not retain the API key.

### Built-in applications

- Web browser powered by Qt WebEngine.
- Persistent PTY terminal.
- Full and region screenshot capture, screen recording with a persistent red
  indicator, in-context preview, and photo/video storage.
- SpaceCapsule workspace manager.
- iPhone Screen Relay as a movable, resizable, pinnable spatial window, using an explicitly started ReplayKit broadcast over encrypted local Wi-Fi.
- Settings, system information, update center, network, and Bluetooth management.
- Integrated Android application environment through Waydroid on the YUNSH Wayland session; its background preparation never blocks the desktop or activation flow.
- Android preparation reports failed or stale background setup with an explicit
  retry action instead of leaving the interface in an endless preparing state.
- Built-in Android app catalogue with a verified F-Droid catalogue, plus APK side-loading through `yunsh-android install-apk`.

### Device services

- A multilingual Hello welcome that repeats until the user selects Continue,
  followed by a touch-first activation flow with separate local YUNSH-account
  and device-unlock passwords. The YUNSH-account password is stored as a
  PBKDF2-SHA256 hash; changing either credential never changes the other.
- Smart Wake is the default: automatic display-off turns the AR surface black
  and can be resumed immediately. An explicit local Lock requires the device
  password before returning to the desktop; Orbit and YUNSH Link cannot bypass
  that local check.
- Settings can verify and change only the Linux user `yunsh` device-unlock
  password later; the local YUNSH-account credential remains unchanged.
- Separate, skippable glasses and iPhone pairing pages with visible progress.
- Case-insensitive one-time phone pairing keys; no QR code or camera is required.
- Optional, skippable Comfort DNA setup.
- Optional, skippable Orbit setup with provider, model, API key, and voice selection.
- Wi-Fi and Bluetooth management.
- OTA update service and factory-reset workflow.
- Power, input, splash-screen, screenshot, recording, lock, and destructive
  action confirmation services.
- Optional 3DoF input through a Bluetooth-connected motion controller or compatible orientation source.

### YUNSH Link connection modes

YUNSH Link is the companion application for the YUNSH display and YUNSH OS. It uses one of two mutually exclusive Bluetooth connection modes, selected for the active experience.

After YUNSH Link pairs the phone, the standalone Orbit app can reuse that
device-bound pairing to discover the system over the encrypted local link.
Actions still run on YUNSH OS under the same permission and destructive-action
confirmation rules as the glasses interface.

| Mode | iPhone connection | System behavior |
| --- | --- | --- |
| **Phone Mode** | Connects directly to `YUNSH V1 (Glasses)` | Reads motion and glasses battery status, and sends display-brightness controls. This mode is for direct glasses use; Bluetooth carries control and telemetry, not display video. |
| **YUNSH OS Mode** | Connects only to the Raspberry Pi advertising as `YUNSH V1` | The Raspberry Pi connects to the glasses, relays glasses telemetry and brightness control, reports host power, and receives companion-initiated update requests over its own network connection. |

Only one mode is active at a time. In YUNSH OS Mode, the iPhone does not also connect directly to the glasses; the Raspberry Pi is the single connection and telemetry hub. The encrypted BLE characteristics are additionally protected by a short-lived, single-use YUNSH pairing key shown on the display. Key entry is case-insensitive.

Screen Relay uses Apple's public ReplayKit broadcast UI and always requires an explicit iPhone confirmation. Video frames use encrypted local Wi-Fi or the iPhone hotspot; Bluetooth remains the pairing, command, and telemetry path. YUNSH Link cannot silently capture iOS or split unrelated iOS apps into separate windows.

YUNSH Flow follows the same transport boundary: content uses paired TLS local
network transfer, while Bluetooth remains for discovery and compact control.
Outdoors, the Raspberry Pi or future compute module can reconnect to a saved
iPhone Personal Hotspot; iOS still requires the user to enable that hotspot.
Clipboard access is initiated by an explicit button and never polled silently.

## Architecture

```text
Binocular AR Display Controller
    │ HDMI · one full frame mirrored to both eye displays
Raspberry Pi 5
    ├── YUNSH OS shell · persistent YUNSH META Universe world layer
    ├── Orbit system agent · provider/model configuration · local tools
    ├── Qt Quick workspace · optional future SBS compositor
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
| Display | Current HDMI controller that mirrors one full frame to both eye displays, or a conventional monitor |
| Storage | 16 GB or larger A2 microSD card recommended |
| Input | Touch/gaze-compatible pointer, YUNSH Link, or a mouse; no physical keyboard is required for activation or recentering |
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

The initial setup creates the fixed Linux `yunsh` service account before any
package transaction, downloads the required desktop and media packages,
including the Raspberry Pi 5 DRM/KMS, EGL, OpenGL, Vulkan, FFmpeg, and OCR
runtime, then reboots once into activation. Connect Ethernet before first
power-on. The graphical desktop requires the Pi 5 DRM/KMS card and starts
Weston with the Pixman renderer as the primary Wayland path; if that path
cannot start, the service reports an error instead of silently switching to a
legacy framebuffer surface. Activation
starts with multilingual Hello, then guides language,
Wi-Fi, optional glasses and YUNSH Link pairing, a local account, optional Orbit
provider/model/key/voice configuration, and optional Comfort DNA. Completing
or skipping activation creates a persistent activation marker, so later boots
open the desktop directly.

The Pi-side YUNSH Link BLE service advertises the separate OS service and keeps
phone pairing available during setup. The iPhone still must complete the
user-approved six-digit pairing flow; a successful Pi-side advertisement does
not by itself prove a full iPhone session.

Factory reset clears user data, saved Wi-Fi networks, Bluetooth pairings, and the activation marker. It preserves YUNSH OS, installed desktop dependencies, and the current system version, then returns to activation on the next boot.

## Motion tracking

YUNSH OS supports optional Bluetooth-connected motion tracking for spatial interaction. The head-tracking bridge provides a consistent interface for compatible motion sources and for the built-in development simulator. After tracking is available, each floating window can be placed directly in a front, left-angle, right-angle, or distance layout from its title bar. The current direction can be recentered from the always-available standalone Recenter button or YUNSH Link on iPhone. A keyboard shortcut remains available for development.

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

The primary image build leaves display timing to the connected controller's
EDID and does not force a legacy 1920×1080 kernel mode. YUNSH OS requires a
DRM/KMS card and uses Weston/Wayland with the software Pixman renderer; it does
not silently downgrade to Qt `linuxfb`. YUNSH OS outputs one complete frame by
default; the current glasses controller is responsible for showing that same
frame on both displays.

## Project status

YUNSH OS is an active prototype for YUNSH spatial computing hardware. The
v3.1.3 release line is validated through static QML, Python, shell, image
structure, partition, boot configuration, ext4, embedded-file, and
systemd-link checks. A clean ARM64 generic-virt test completed firstboot,
downloaded packages with MB progress, crossed the former 42% handoff,
validated SSH and desktop prerequisites, wrote the completion marker, and
automatically rebooted. After reboot, SSH, `yunsh-os.service`, and the
post-reboot health guard were reachable. Generic virt machines do not provide
the Raspberry Pi 5 DRM/fb scanout, so this test does not claim a Pi 5 display,
mouse, Bluetooth, Android, or optical-display hardware result.

## License

Copyright © 2024–2026 YUNSH. All rights reserved.
