# Test Plan

## Performed in this lane

- Patch will be verified using `git apply --check --whitespace=error-all` against exact main.
- Engine XCTest source stages five focused test methods: 100 unique rituals, ten forms per tone, deterministic daily selection, non-treatment wording, and breathing pacing.
- Swift/Xcode/XCTest execution is **NOT RUN** until a Swift/iOS environment is available. The current workspace has no `swiftc` or Apple SDK; no pass is claimed.

## Required before integration

1. `xcodegen generate --spec project.yml` and iOS 15 Debug build.
2. Run `VeilEmotionGardenEngineTests` and full `VeilLinkTests`.
3. iPhone 7: open/close sheet, tone selector scroll/tap, compact widths, keyboard-free navigation, scrolling and memory profile.
4. Accessibility: VoiceOver labels/order, largest Dynamic Type, increased contrast, Reduce Motion and light/dark modes.
5. Safety review: no language implies diagnosis, guaranteed improvement, dependency, surveillance or emergency-service replacement.
6. Privacy check: prove no user text/mood selection leaves the process; verify no third-party payload was introduced.
7. Re-run consent/signing P0 acceptance matrix before any release or IPA action.

