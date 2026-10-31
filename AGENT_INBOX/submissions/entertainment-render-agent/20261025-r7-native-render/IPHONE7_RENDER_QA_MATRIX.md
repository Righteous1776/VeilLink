# Wave 1 physical device test matrix — PENDING

| Target / mode | Canvas and controls | Clock and lifecycle | Metric to capture |
|---|---|---|---|
| iPhone7 iOS15.8.3 portrait light | full 390x600 virtual canvas letterboxed; 4 fixed dock buttons tap at corners | start → pause → resume → 4-district clear | screenshots, p50/p95 callback intervals, visible artifacts |
| iPhone7 iOS15.8.3 portrait dark | match above with appearance switch, no overlays | repeated foreground/background, 280ms stale snapshot | full-screen screenshots and hit-area recording |
| iPhone13+ portrait | correct aspect, no stretched notes, no clipped HUD | 15ms sampler clock skew and dropped HUD frame | profile thermal/power and event-to-judgement time |
| iPad 4:3 portrait/landscape | aspectFit safe insets, no press targets covered | rotation, multitasking and safe-area changes | viewport snapshots, touch matrix |

### Enforcement

- Do NOT claim GPU time or achieved FPS from `VeilRenderFrameStats`: it tracks SpriteKit callback intervals only.
- Avoid changing scene scaleMode to `.resizeFill` without a complete layout refactor.
- Do NOT use real chat content, radio identity, keychain values or user locations in graphics telemetry.
- 20-minute A9 thermal/foreground test to be run physically, signed by Governor with evidence location.
- Any FAIL freezes Wave 1, even if Linux XCTest passes.
