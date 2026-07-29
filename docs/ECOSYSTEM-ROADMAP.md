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

## YUNSH OS v2.0.0

YUNSH OS v2.0.0 combines the binocular spatial-display foundation with the
first transferable workspace and personal comfort-profile experiences:

- exportable and restorable `.yunshspace` SpaceCapsule files;
- an optional, skippable Comfort DNA step during activation;
- steady, balanced, and responsive local comfort profiles;
- AR-visible white liquid-glass application surfaces over an optical-black
  transparent canvas;
- synchronized side-by-side output for left and right eye views;
- EDID-driven display output without a forced legacy 1080p mode;
- calibration for IPD, horizontal fusion, field of view, crop, and eye order;
- a shared comfortable focal plane for the system shell;
- 30 Hz 3DoF head-pose sampling, smoothing, yaw wrap handling, roll
  compensation, and one-action recentering;
- direct front, left-angle, right-angle, and distance window layouts;
- window pin and follow behavior;
- focus mode, reduced motion, reduced transparency, and increased contrast;
- validated, persistent display and comfort preferences.

Release assets are published through
<https://github.com/ljcccc999/yunsh-os/releases>. Structural image validation
does not replace physical validation. Optical comfort, display-controller
compatibility, Raspberry Pi boot, Bluetooth motion hardware, and peripheral
behavior still require testing on the intended prototype.

The current shell duplicates a single application surface into both eye
viewports. It does not claim per-eye stereoscopic application rendering, 6DoF
tracking, or real-world room anchoring.

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

### Planned experiences

- **YUNSH Drop:** send selected photos, videos, files, web links, and text from
  an iOS Share Extension to YUNSH OS.
- **YUNSH Handoff:** continue supported URLs, reading positions, documents, and
  YUNSH application state between the phone and the spatial desktop.
- **YUNSH Universal Clipboard:** synchronize explicitly shared clipboard
  content through YUNSH Link or a Shortcut.
- **YUNSH Screen Relay:** place a user-authorized iPhone screen stream in one
  YUNSH spatial window.

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

## YUNSH Orbit

**YUNSH Orbit** is the working product name for the planned system AI agent.
“Orbit” reflects YUNSH's atomic identity and the agent's role in coordinating
applications, devices, content, and spatial work around the user. The technical
runtime may be called **YUNSH Agent Runtime**. The product name requires a
trademark and market-conflict check before commercial launch.

### Experience

Orbit is intended to understand requests such as:

- “Open my study space.”
- “Put the browser on the left and my notes in front.”
- “Send this page to my iPhone.”
- “Save this workspace as a SpaceCapsule.”
- “Reduce motion and make the windows more comfortable.”

Text input through YUNSH OS and YUNSH Link is the first dependable interface.
Voice input is conditional on a future microphone-equipped hardware
configuration and is not assumed by the current hardware.

### Runtime architecture

Orbit should use a local orchestrator such as `yunsh-agentd`, not give a remote
model unrestricted system access.

```text
User
  │
YUNSH Orbit UI
  │
yunsh-agentd
  ├── local context and conversation state
  ├── permission and confirmation broker
  ├── allow-listed OS tools
  └── encrypted request
        │
        ▼
YUNSH AI Gateway
  ├── YUNSH key authentication
  ├── quota, rate, model, and device policy
  ├── billing and abuse controls
  ├── minimal audit and usage records
  └── server-side model-provider credential
        │
        ▼
Model provider API
```

The model may propose tool calls, but the local broker owns execution. File
access, screen content, account data, settings changes, purchases, deletion,
and other sensitive operations require narrowly scoped permissions and, when
appropriate, an explicit confirmation. Raw shell access is not a model tool.

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

The initial provider may be DeepSeek, but the YUNSH contract and gateway should
remain provider-neutral. Current DeepSeek Open Platform terms allow integration
into downstream services for end users and require the developer's API key to
remain secret. Before launch, YUNSH must re-check the current provider terms,
pricing, regional availability, privacy requirements, content-safety duties,
payment rules, tax obligations, and any rules that apply to selling digital
credits.

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

1. Stabilize v2.0.0, SpaceCapsule, and Comfort DNA on the real binocular
   display, Raspberry Pi, tracking controller, and YUNSH Link hardware path.
2. Build YUNSH Flow pairing and YUNSH Drop over the local network.
3. Build the YUNSH AI Gateway, entitlement service, metering, and a text-only
   Orbit prototype with read-only tools.
4. Add permissioned window, settings, Flow, and SpaceCapsule tools to Orbit.
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
