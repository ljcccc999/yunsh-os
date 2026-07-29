# YUNSH OS — Design Principles

> Adapted from Apple's WWDC design talks (Designing Fluid Interfaces 2018)
> and Emil Kowalski's [skills](https://github.com/emilkowalski/skills) for design engineers.

## 1. Instant Response (反馈即触达)

Feedback lives on **pointer-down**, not pointer-up. The moment lag appears, directness dies.

- Highlight buttons immediately on press, not on release
- Audit every debounce, timer, and transition delay
- During drag/swipe: update UI 1:1 with input every frame

```qml
// ✓ Good: instant feedback on press
Button {
    onPressed: scaleAnim.to = 0.97
    onReleased: scaleAnim.to = 1.0
}
```

## 2. Direct Manipulation (直接操控)

Touch and content move together — 1:1 tracking with the input device.

- Keep pointer-relative grab offset (don't snap to center)
- Use `setPointerCapture`/`MouseArea.drag` for continuous tracking
- Content must stay glued to the cursor/finger during drag

## 3. Interruptible Animations (可中断动画)

Every animation must be interruptible mid-flight. A user grabs a moving element → it follows their input, not finishes first.

- Never lock out input during transitions
- Animate from the **current on-screen value**, not the target
- Avoid CSS transitions for gesture-driven motion (can't interrupt)
- Use property animations with `easing.type: Easing.OutSpring` for gesture interactions

## 4. Springs Over Fixed Duration (弹簧替代固定时长)

Springs are inherently interruptible and velocity-aware. Fixed-duration animations can't respond to new input.

```qml
// ✓ Good: spring-based animation
NumberAnimation {
    duration: 400
    easing.type: Easing.OutSpring
    // Over-damping 0.8 for momentum interactions, 1.0 for general UI
}
```

- Damping 1.0 = critically damped (no bounce, default for most UI)
- Damping ~0.8 = slight bounce (only for momentum-driven gestures)
- Decompose 2D motion into independent X/Y springs

## 5. Velocity Preservation (速度传递)

When a gesture ends, animation inherits the finger's exact velocity. No seam between drag and animation.

- Pass gesture velocity to the animation as initial velocity
- Project momentum forward before snapping to nearest boundary

## 6. Momentum Projection (动量投影)

Flick = throw. Use velocity to project resting position, then snap.

- Apply Apple's exponential-decay projection: `v·d/(1-d)` where d ≈ 0.998
- For scroll, carousel, sheet dismiss: project then snap, never snap-from-release

## 7. Spatial Consistency (空间一致)

Enter and exit along the same path. Panel slides in from right → dismisses to right.

- Anchor interactions to their trigger origin
- Mirror easing on reversible transitions (inverse cubic-bézier for return)

## 8. Progressive Resistance (渐进阻力)

At boundaries, resist progressively (rubberband). Hard stop = frozen; soft resistance = alive.

```qml
// Rubberband function for edge resistance
function rubberband(overshoot, dimension, constant = 0.55) {
    return (overshoot * dimension * constant) / (dimension + constant * Math.abs(overshoot))
}
```

## 9. Glass/Material Design (玻璃材质)

### Material Hierarchy
- The global canvas remains pure black because optical black is transparent on
  the target AR display.
- Application surfaces use luminous white liquid glass so their boundaries
  remain visible over the real world.
- Bigger surfaces = thicker glass (more blur + deeper shadow)
- Small interactive elements = lighter, more transparent material
- Color lives on solid layers *behind* glass, never on translucent foreground

### Materialize Animation
Glass surfaces animate in with **simultaneous scale + blur + opacity**, not just fade.
```qml
// Enter: scale 0.95 → 1.0 + opacity 0 → 1
// Exit: scale 0.92 + opacity 0 (reverse)
```

### Edge Fade
Replace 1px dividers with gradient fades at scroll boundaries. Soft blur gradient > hard border.

### Vibrancy
Over glass surfaces: higher contrast, slightly heavier weight, small letter-spacing bump.

## 10. Reduced Motion (减少动效)

Three independent signals:
- `prefers-reduced-motion: reduce` → opacity cross-fade, no spring/parallax/scale
- `prefers-reduced-transparency: reduce` → raise opacity, drop blur
- `prefers-contrast: more` → solid backgrounds, defined borders

Always avoid:
- Full-viewport moving backgrounds
- Slow looping oscillations (~0.2 Hz)
- Abrupt brightness jumps
- Large moving objects at full opacity

```qml
// Example: reduced-motion fallback
Behavior on opacity {
    NumberAnimation { duration: 200 }
}
// No spring/scale animations — just opacity cross-fade
```

## 11. Binocular Comfort (双目舒适度)

The system shell is rendered as a synchronized side-by-side frame on a shared
focal plane. Comfort and predictability take priority over exaggerated depth.

- The left surface is the interaction source; the right surface is copied on
  the GPU from the same frame.
- IPD metadata, horizontal fusion offset, field of view, crop, and eye order
  are checked with a dedicated calibration target.
- The compositor fills each eye viewport. The display controller advertises
  the native combined mode through EDID and performs panel-specific unpacking.
- Shell windows use scale, yaw, and occlusion as conservative depth cues.
  True stereo applications require a future distinct per-eye rendering path.
- Never present a 3DoF view-relative layout as a 6DoF world anchor.
- Recenter must be available without leaving the current task.
- Recenter must not require a physical keyboard: keep a persistent virtual
  control and accept the same explicit command from YUNSH Link.

## 12. Agency and Focus (控制权与专注)

- Spatial placement is selected directly from a four-position menu.
- Focus mode removes nonessential chrome and dims inactive windows without
  claiming to dim the real world.
- Display and comfort preferences are validated, persisted atomically, and
  reset with user preferences during factory reset.
- Reduced motion, reduced transparency, and increased contrast are independent
  choices.
- Comfort DNA is optional during activation, can be skipped without blocking
  setup, and remains editable in Settings.
- SpaceCapsule exports only allow-listed workspace state; it never treats
  terminal history, credentials, or arbitrary application data as transferable.
- Nearby SpaceCapsule delivery is encrypted, verifies the announced endpoint
  identity, and waits for receiver approval.
- Phone pairing uses an encrypted BLE characteristic plus a short-lived,
  single-use, case-insensitive key shown on the display. It never requires a QR
  code or camera.
- Screen Relay is visible only after the user starts Apple's ReplayKit
  broadcast UI. Local-network video is encrypted and cannot start silently.

## QML Implementation Notes

| Principle | Key Files |
|-----------|-----------|
| Glass material | `GlassBackground.qml`, `GlassCard.qml`, `GlassPanel.qml`, `MacWindow.qml` |
| Materialize animation | `GlassBackground.qml` (onCompleted scale+opacity), `MacWindow.qml` |
| Interruptible motion | `VirtualKeyboard.qml`, `TaskSwitcher.qml` |
| Reduced motion | `Screensaver.qml` |
| Spatial consistency | `ActivationScreen.qml`, `SettingsScreen.qml` |
| Binocular output | `StereoCompositor.qml`, `StereoCalibration.qml` |
| Display comfort | `SpatialDisplaySettings.qml`, `SliderRow.qml` |
| Personal comfort | `ComfortDnaScreen.qml` |
| Workspace transfer | `SpaceCapsuleScreen.qml`, `main.qml` |
| iPhone screen window | `ScreenRelayScreen.qml`, `main.qml` |
| 3DoF interaction | `main.qml`, `MacWindow.qml`, `ControlCenter.qml` |
