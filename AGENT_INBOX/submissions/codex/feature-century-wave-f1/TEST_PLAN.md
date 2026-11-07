# Test Plan

## Completed in this lane

- `git apply --check PATCH.diff`: PASS against exact base main `501ef814...`.
- Patch path audit: PASS; proposed product patch contains three new files and one additive Tool Center hunk.
- Source inventory: PASS; full copies of every new proposed file are under `FILES/`.
- XCTest source: 9 focused test methods staged.
- `swiftc` / Xcode / XCTest execution: NOT RUN — this Linux container has no `swiftc` or Apple SDK. This is recorded as pending rather than reported as a pass.

## Required integration validation

1. `xcodegen generate --spec project.yml`.
2. iOS 15 simulator Debug build with warnings treated as review findings.
3. Run `VeilProductivityEngineTests` and the full `VeilLinkTests` suite.
4. Confirm malformed templates, arbitrary placeholder whitespace and Unicode variable names.
5. Confirm diff determinism, empty input, 400/401-line and 64-KB boundaries.
6. Confirm merge never silently chooses one side when both differ from the baseline.
7. Confirm DST transitions and invalid IANA identifiers.
8. Confirm traversal separators, Unicode-equivalent duplicates, negative/zero sizes, extension case folding, count/size/overflow limits.
9. UI: iPhone 7 / iOS 15, keyboard entry, ScrollView/tap behavior, largest Dynamic Type, VoiceOver, light/dark mode and Reduce Motion.
10. Re-run the consent/signing P0 matrix before any release; do not dispatch IPA workflows from this submission.

