# YUNSH OS Ecosystem Roadmap

This document separates shipped capabilities from product direction. Planned
work is not a statement of current hardware or software support.

## Product foundation

YUNSH is a spatial-computing ecosystem:

1. YUNSH AR is the wearable entry point.
2. YUNSH OS is the connection and spatial-computing layer.
3. The persistent spatial world is the long-term platform.

The portable Raspberry Pi or future YUNSH compute module remains the primary
computer. An iPhone is a close companion and data bridge. A Mac, PC, or cloud
service may add compute capacity when available, but normal outdoor operation
must not depend on one.

## YUNSH OS v2.0.1

YUNSH OS v2.0.1 preserves every v2.0.0 workspace and comfort capability and
adds the persistent system-world foundation and Orbit system agent:

- exportable and restorable `.yunshspace` SpaceCapsule files;
- encrypted nearby YUNSH Drop between YUNSH OS devices, with receiver approval;
- YUNSH Link workspace import and iOS share-sheet forwarding;
- user-authorized iPhone Screen Relay as a normal spatial window;
- separate skippable glasses and phone pairing pages with progress;
- a case-insensitive, short-lived, single-use phone pairing key with no QR code;
- a persistent virtual Recenter control and YUNSH Link recenter command;
- an optional, skippable Comfort DNA step during activation;
- steady, balanced, and responsive local comfort profiles;
- AR-visible white liquid-glass application surfaces over an optical-black
  transparent canvas;
- one complete default output frame mirrored to both eye displays by the
  current glasses controller;
- optional advanced side-by-side compatibility for a future independent-eye controller;
- EDID-driven display output without a forced legacy 1080p mode;
- calibration for IPD, horizontal fusion, field of view, crop, and eye order;
- a shared comfortable focal plane for the system shell;
- 30 Hz 3DoF head-pose sampling, smoothing, yaw wrap handling, roll
  compensation, and one-action recentering;
- direct front, left-angle, right-angle, and distance window layouts;
- window pin and follow behavior;
- focus mode, reduced motion, reduced transparency, and increased contrast;
- validated, persistent display and comfort preferences.
- three permanent liquid-glass YUNSH / METAVERSE / Orbit buttons;
- YUNSH META Universe as a shell-owned world layer rather than an application;
- Orbit auto-start, provider/model/own-key configuration, encrypted local
  credentials, plan–act–observe–verify execution, first-use capability
  approval, destructive-action confirmation, screen observation, recording,
  semantic shell control, task plans, memory, and optional voice;
- default sweet female speech, optional male speech, and honest USB/Bluetooth
  microphone detection with background voice preparation.
- one shared on-device Orbit runtime across the glasses conversation panel and
  a standalone Orbit iPhone app, using YUNSH Link pairing and the
  TLS-encrypted local-network path.

Release assets are published through
<https://github.com/ljcccc999/yunsh-os/releases>. Structural image validation
does not replace physical validation. Optical comfort, display-controller
compatibility, Raspberry Pi boot, Bluetooth motion hardware, and peripheral
behavior still require testing on the intended prototype.

The current display controller duplicates one complete YUNSH OS output frame
to both physical displays. Optional SBS does not claim per-eye stereoscopic
application rendering, 6DoF tracking, or real-world room anchoring.

## Workspace and comfort

### YUNSH SpaceCapsule

SpaceCapsule captures a live workspace as a portable spatial object. It is
implemented in v2.0.0 and preserves supported application selection, window
placement, size, spatial preset, pin/follow mode, and selected safe application
state. The first supported application state is the browser URL.

Examples include a study capsule, a travel capsule, or a collaborative project
capsule. Applications that do not expose restorable state will fall back to a
safe launch target rather than pretending to support full state restoration.
Terminal history, credentials, and arbitrary private application data are not
included.

### YUNSH Comfort DNA

The v2.0.0 Comfort DNA foundation offers explicit steady, balanced, and
responsive profiles. It adjusts local head-tracking smoothing, field of view,
and reduced-motion behavior. The activation step is optional and can be
skipped, and the profile remains available in Settings.

Future opt-in versions may derive recommendations from calibration choices and
motion behavior. They must remain transparent and user-controlled, show what
changed, provide a reset, avoid medical claims, and keep raw motion history
local unless the user explicitly chooses otherwise.

## Planned Adaptive Compute

Adaptive Compute keeps the wearable experience running on the portable YUNSH
computer and adds optional compute resources without making them mandatory.

- **Standalone:** Raspberry Pi or a future pocket/neck compute module runs the
  spatial desktop and core applications.
- **Companion:** iPhone provides approved data, networking, input, and
  user-initiated screen relay.
- **Boost:** a nearby Mac, PC, home server, or cloud service may accelerate
  rendering or AI tasks.

Tasks must advertise their requirements before migration. Sensitive local data
must not leave the device without permission, and loss of an optional compute
node must degrade gracefully instead of ending the session.

## YUNSH Flow for iPhone

YUNSH Flow is the planned interoperability layer between YUNSH OS and iPhone.
It should use public Apple APIs and explicit user consent rather than attempting
to reproduce Apple's private ecosystem protocols.

### v2.0.0 foundations

- **YUNSH Drop:** send SpaceCapsules directly between nearby YUNSH OS devices,
  or import them into YUNSH Link and forward the file through the iOS share
  sheet to WeChat, Files, AirDrop, or another installed app.
- **YUNSH Handoff:** continue supported URLs, reading positions, documents, and
  YUNSH application state between the phone and the spatial desktop.
- **YUNSH Universal Clipboard:** synchronize explicitly shared clipboard
  content through YUNSH Link or a Shortcut.
- **YUNSH Screen Relay:** place a user-authorized ReplayKit iPhone broadcast in
  one movable, resizable, pinnable YUNSH spatial window.

### Connection design

Bluetooth Low Energy is suitable for discovery, pairing bootstrap, lightweight
control, telemetry, and certificate exchange. Bonjour discovery and an
encrypted local Wi-Fi channel should carry files and screen video. The devices
may use the same Wi-Fi network or an iPhone hotspot; Bluetooth is not the video
transport.

Pairing should establish device identity once, require confirmation on both
devices, and use mutually authenticated encrypted sessions afterward.

### Platform boundaries

YUNSH Flow cannot extract arbitrary iOS application data, read the entire iOS
notification center, silently monitor the clipboard, silently capture the
screen, control arbitrary iOS applications, or split unrelated iOS
applications into independent YUNSH windows. Background work, local-network
access, screen capture, and data sharing remain subject to Apple permissions
and review rules.

## Orbit

**Orbit** is the product name used in YUNSH OS v2.0.1. It is a system runtime,
not a normal application, and starts at every boot independently from the
desktop process. Its current black-and-white open-O mark is integrated as the
working product icon.

### Experience

Orbit accepts requests such as:

- “Open my study space.”
- “Put the browser on the left and my notes in front.”
- “Send this page to my iPhone.”
- “Save this workspace as a SpaceCapsule.”
- “Reduce motion and make the windows more comfortable.”

Text input is always available. Optional speech uses a sweet female voice by
default with a male alternative. Voice recognition activates only when a USB
or Bluetooth microphone is detected; an integrated glasses microphone is not
assumed.

### Runtime architecture

The v2.0.1 runtime is `/usr/bin/orbitd`. Its HTTP API binds only to loopback.
Users choose DeepSeek, Kimi, or a custom OpenAI-compatible endpoint, choose a
model, and enter their own API key. The key is encrypted at rest with a
device-local key and is never returned in full.

```text
User
  │
Orbit UI
  │
orbitd
  ├── local context and conversation state
  ├── user-selectable capability switches and first-use approval
  ├── system tools and UI command bridge
  ├── device-key-encrypted provider credential
  └── selected model-provider API
```

The model proposes tool calls and the local runtime owns execution. Capability
categories can be disabled in settings; enabled categories still ask for
Allow Once, Always Allow, or Deny when a sensitive tool is first used.
Destructive commands and power/recovery actions always require fresh approval
and cannot be permanently trusted. Raw shell remains trusted-device access.

### Commercial access and quotas

YUNSH can sell metered **YUNSH AI access or credits** through its own gateway.
It should not sell, disclose, or embed the upstream DeepSeek API key.

Each customer receives a revocable YUNSH credential associated with an account
and entitlement. Server-side policy can enforce:

- prepaid or subscription token/credit allowance;
- daily and monthly budgets;
- per-minute requests and concurrent-session limits;
- maximum input and output size;
- allowed models and tools;
- expiration, device count, and optional device binding;
- suspension, rotation, and recovery after suspected compromise.

Usage must be metered from the provider's returned usage data and reconciled
server-side. Client-side counters are only a display and cannot be the authority
for billing. The gateway must use idempotency controls so retries cannot charge
the user twice.

The optional future YUNSH AI Gateway and quota business remain provider-neutral
and separate from the v2.0.1 bring-your-own-key mode. If YUNSH later sells AI
credits, upstream keys must remain server-side and the service must re-check
current terms, pricing, privacy, safety, payment, tax, and regional rules.

### Privacy and resilience

- Clearly disclose when prompts, attachments, or screen content will be sent
  to a remote provider.
- Require explicit consent before transmitting files or screen content.
- Redact credentials and other known secrets before upload.
- Keep the upstream key in a server-side secret manager and rotate it safely.
- Minimize stored prompt content; keep billing and security records separate.
- Preserve local commands and a clear offline state when the AI service or
  internet connection is unavailable.

## Delivery sequence

1. Stabilize v2.0.1, SpaceCapsule, Comfort DNA, the mirrored display path,
   the system world, and Orbit on the real binocular
   display, Raspberry Pi, tracking controller, and YUNSH Link hardware path.
2. Build YUNSH Flow pairing and YUNSH Drop over the local network.
3. Validate Orbit provider calls, voice peripherals, and full-permission tools
   on the Raspberry Pi hardware, then add narrower confirmations where useful.
4. Build the optional YUNSH AI Gateway, entitlement service, and metering.
5. Validate Comfort DNA profiles and future opt-in recommendations with
   physical-hardware testers.
6. Add Adaptive Compute only after task migration, privacy, recovery, and
   latency behavior are measurable.

## Reference boundaries

- [DeepSeek Open Platform Terms of Service](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html)
- [DeepSeek API rate limits and user isolation](https://api-docs.deepseek.com/quick_start/rate_limit/)
- [DeepSeek API token usage](https://api-docs.deepseek.com/quick_start/token_usage/)
- [Apple Local Network Privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
