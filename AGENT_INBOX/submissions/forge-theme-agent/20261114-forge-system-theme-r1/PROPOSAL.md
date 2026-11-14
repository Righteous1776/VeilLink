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
