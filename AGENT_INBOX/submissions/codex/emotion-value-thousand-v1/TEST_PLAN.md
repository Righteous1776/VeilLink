# Test Plan

## Performed in this lane

- `git apply --check --whitespace=error-all PATCH.diff` against exact main: PASS.
- Catalog: 1,000 rows, 1,000 unique sequential IDs `EV-0001...EV-1000`: PASS.
- Swift 6.2 Linux container, strict-concurrency engine typecheck: PASS.
- Swift frontend parse of the proposed SwiftUI and XCTest source: PASS. This verifies syntax only, not Apple SDK symbols.
- Compiled runtime harness: PASS with output `EMOTION_RUNTIME_1000_PASS`; it executes assertions for 1,000 unique IDs, prompts, three-step sequences and completion reflections, all 10 × 10 × 10 combinations reachable, and deterministic daily selection.
- Five focused XCTest methods are staged but **XCTest has not been executed** as an app test bundle.
- Xcode/iOS SDK/iPhone execution: NOT RUN; no pass is claimed.

## Required before integration

1. `xcodegen generate --spec project.yml` and iOS 15 Debug build.
2. Run `VeilEmotionGardenEngineTests` and full `VeilLinkTests`.
3. iPhone 7: open/close sheet, tone selector scroll/tap, compact widths, keyboard-free navigation, scrolling and memory profile.
4. Verify countdown start/pause/resume/reset/completion for 30/45/60/75/90-second variants, background/foreground transitions and sheet dismissal cancellation.
5. Accessibility: VoiceOver labels/order, largest Dynamic Type, increased contrast, Reduce Motion and light/dark modes.
6. Safety review: no language implies diagnosis, guaranteed improvement, dependency, surveillance or emergency-service replacement.
7. Privacy check: prove no user text/mood selection leaves the process; verify no third-party payload was introduced.
8. Re-run consent/signing P0 acceptance matrix before any release or IPA action.

