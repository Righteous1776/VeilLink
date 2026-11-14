# FORGE // 06 · Industrial Mechanical Theme R1

## Owner intent
Build a COMPLETE, independently selectable VeilLink theme instead of applying superficial particle or mechanical animations to every existing style. Inspired by the owner's existing ECLIPSE Gomoku identity card and compute module: graphite/black instrument hardware, sharp orange as a functional signal color, strict sans/monospace, mechanical status visualizations. Preserve all existing theme choices and all core app functions.

## Exact main basis
- `AppearanceTheme.swift` currently has five persisted `VeilAppearanceSelection` cases and palettes. The new case `.forge` uses the existing stored selection key, keeping old values valid.
- `AppTheme.swift` houses shared gradient, `VeilPanelShape`, global background and `VeilCardModifier`; FORGE adds its own material routing while keeping existing themes unchanged.
- `VeilEclipseComputeConsole.swift` expresses telemetry with dark monospaced measured/pseudo-labelled displays; FORGE follows the structural visual grammar but never presents fictitious metrics.
- `NearbyView.swift` has a radar ripple/sweep. Only when FORGE is selected, replace it with a mechanical RF actuator; other themes keep the old radar until separate owner-directed migration.

## Theme shell (new, not a recolor)
1. New `FORGE · 锻造` entry in Settings > 外观主题; persisted independently alongside Veil 原生 / Apple Soft / 拟物仪器 / 白描 / 浮屿. Support system/Light/Dark by two dedicated semantic palettes.
2. Black graphite (night) and machined aluminum (day); orange signal-only accent, off-white engineering text, green/red reserved for real valid/error states.
3. Shared design primitives: static Cartesian engraved grid on the background; sharp cut-corner metal plates, dual-tone bevel, corner fiducials; high-tactility press/resolve motion without rubbery bounce or particles.
4. Scoped status instrumentation: 24-notch RF/CPU stepper motors bound to actual scan/loading/generating states, 12Hz deterministic and background/reduced-motion/low-power gated. BLE health has eight bars mapped to genuine `linkSnapshot.healthScore` (never speed/battery/progress). Data rails show actual Nearby peer count, LAN connected & secure counts, Agent runtime state.
5. All UI indicators are local, no root overlays, no infinite particle canvas, no intercepted gestures. Feature-specific ECLIPSE board thinking remains intact and picks up the new palette automatically.

## Integration stance
This is a new core theme lane, more comprehensive than #231's standalone all-theme mechanical retrofit. Governor should treat #231 as superseded for UI selection/rotor design and reuse only after explicit overlap arbitration; do not apply both raw patches. #229 global particle removal is compatible but separately required and still in the Inbox. No application build has run in this Inbox stage.

## Continuation verification record (2026-11-14)
The staged patch has been repaired to use the existing palette metal fields and replayed against the exact base for all seven product files. The deterministic Foundation motion core compiled on Linux and passed 17 value checks. App-level and theme case XCTest remain unrun until Apple CI. The required palette-selection regression XCTest is now included in the proposed test file. This is **not** a merged or released change.

## R2 screenshot-grounded redesign (owner's three live Gomoku screenshots)

These photos show: (1) saturated orange reserved for high-priority controls, dark graphite background with floating dust from legacy particles; (2) a thick charcoal ECLIPSE ID card with near-black `VISUAL STREAM`, bold white name, clear orange accent and a large chess board; (3) training/settings dense with nested gray plates, orange action switches, many simultaneous telemetry labels and scrolling. The referenced ECLIPSE compute stream is decorative by its existing code's own disclosure; FORGE must not misrepresent synthetic visual code as real engine metrics.

**New R2 changes**, all still inside this exact-base Inbox patch:
- Night palette's signal orange is adjusted to a screenshot-derived vivid orange (`Color(red:0.98,green:0.38,blue:0.11)`) instead of gold/yellow. Existing day-mode separate contrast palette retained.
- Two context-sensitive, **non-interactive** system headings inspired by ECLIPSE's hardware ID plate: `VL / RF-01` real scanning/standby status; `VL / CPU-02` real native runtime state. Source values only.
- The Settings theme selector now has its own static 42pt chip motif rather than a generic SF Symbol, plus a compact FORGE specification with RF/CPU/BLE role labels when selected. No rendered fake percentages or continuous animation.
- Existing shared `VeilSpatialPressModifier` now **does not install its zero-distance `DragGesture` in FORGE**. This avoids adding any ornamental gesture competitor to Nearby scrolling, chat input and game touch. Existing native `ButtonStyle` press behavior is preserved.
- Existing `VeilDynamicGlowBorder` no longer performs repeat-forever perimeter glows in FORGE and safely resets on theme switching. Other legacy themes preserve their own behavior.
- Game-specific ECLIPSE code, learned positions, training and visual-trace logic remain untouched to avoid collision with the ongoing Gomoku agent work.

These changes are an independent, theme-wide visual foundation; they do NOT alter the screenshots' third-party navigation bar or claim to repair existing keyboard/scroll issues. The global dust/particle layer requires the separately queued PR #229.


## R3 / Five differentiated actuator families (2026-11-15)

Owner explicitly requested a broader FORGE motion language with structurally different mechanisms, not repetitive loops.

| Family | Grounded data | Motion |
| --- | --- | --- |
| RF stepper rotor | bluetooth.isRunning | 12 Hz stepped rotation, foreground scanning only, low-power/reduced-motion gated |
| CPU opposed shutters | coordinator.runtimeState | Two jaw plates slide out while actual loading/generating, settle when ready |
| Peer-count odometer | sessions.nearbyPeers.count | Reuses the native VeilOdometerNumber, rolling actual observed digits on count changes |
| LAN sliding routing carriage | lanTurbo.connectedPeerCount and sessions.secureLANPeerCount() | Transient three-position IDLE / TCP / SECURE selected by real link presence; NOT throughput or transfer progress |
| BLE link-health ratchet | linkSnapshot.healthScore | Eight discrete bars, each settles with a bounded stagger on actual score change |

Mechanical language: rotary / aperture / vertical rolling digits / horizontal sliding carriage / segmented ratchet. Each localized device is visually different. New devices do not add gestures or persistent timers; decorative layers do not intercept touches. Non-FORGE appearance branches and the in-flight Gomoku engine remain untouched. Global particle deletion still requires separately proposed #229.
