# APPLE_SOFT_LIQUID_GLASS_V1

Adds a manually selectable **Apple Soft** UI skin while moving Apple platform materials into a shared, non-user-toggleable material engine.

## Design rules

- Liquid Glass is reserved for controls/chrome, not every content card.
- `Veil Original` and `Instrument Auto` remain available.
- `Apple Soft` replaces cut/metal-heavy surfaces with rounded soft-neumorphic plates, neutral system-like backgrounds, blue brand tint, low-contrast borders and restrained shadows.
- Motion reuses `VeilMotionKit` and follows the Emil Kowalski animation audit rules: short feedback, ease-out entries, interruptible springs, transform/opacity over layout animation, Reduce Motion support.
- Morphicon vectors are native SwiftUI paths; no GIF, Lottie, WebView or JS runtime is introduced.

## iOS 26 strategy

`VeilPlatformMaterialEngine` is the permanent bottom material layer.

- New SDK/compiler: custom controls use native `glassEffect` / `GlassEffectContainer` on iOS 26+.
- Current Xcode 16.x release CI: those declarations are excluded at compile time and the same source uses `.ultraThinMaterial`/soft-neumorphic fallbacks.
- Standard SwiftUI navigation and toolbar controls remain standard so current Apple SDKs can adopt Liquid Glass automatically.
- There is **no user switch for Liquid Glass**. The only manual switch is the UI skin selection.

## Scope

Global primitives changed by the Apple Soft selection: app/root navigation shell, phone bottom dock, tablet rail, background hierarchy, card geometry, glass/material controls, button press behavior, icon-disc treatment, palette and Settings theme picker.

Existing Chat, Nearby, Community, Relay, Background, Agent and Settings screens already depend on shared Veil primitives, so the new visual language propagates without forking the communication logic.

## Compatibility

- iOS deployment floor remains 15.0.
- iPhone 7 legacy compositor keeps simplified shadows and no required persistent decorative animation.
- No communication, database, E2EE, BLE, LAN, Mesh, Internet Relay, QR pairing, legal-gate or Android protocol logic is changed.
