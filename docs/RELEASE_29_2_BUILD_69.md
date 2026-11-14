# VeilLink 29.2 · Build 69 — corrected integration / performance release

## Background

Build 68 `0e4b51e` integrated and published the ten approved Build68 source gates. It did NOT integrate the entire historic Agent Inbox. This corrected build retains the honest scope, advances the build identity, and carries a focused stability repair sourced from PR #243.

## Actual app and test changes

- ImageTranscoder now uses utility-QoS image work with cancellation propagation and checkpoints to reduce expensive encoding work competing with interaction.
- DevicePerformancePolicy adds an iPhone 13/13 mini A15 4 GB performance profile, avoids eager shard precomputation, and coalesces message refresh to reduce perceived stalls.
- Adds deterministic image-task cancellation and device-policy XCTest coverage.
- ECLIPSE live instrument stops 10 Hz refresh while idle or backgrounded, renders four compact two-column measured stats, and shows last-move nodes/second only when real completed metrics exist. This is instrumentation, NOT a claim that the full R17.2 cockpit is integrated.
- Preserves Build68 chat keyboard/order, file import, BLE queue repairs, FORGE visuals, Flight Recorder R5 and game lobby scrolling.

## Explicit limitations / not included

- **VeilScreen R1/R2.1**: NOT shipped. Candidate lacks signed end-to-end authenticated BLE media routing, app-group / entitlement verification, user-consent/device proof, and reliable host-background transmission. Never advertise system screen sharing in this IPA.
- **ECLIPSE full R17.2**: NOT shipped. Hybrid R16/R17 candidate cannot replace present R14 product sources without a semantic rebase and Apple UI testing.
- **Gomoku R8–R14 2,500-pair tournament**: not run. No unsupported Elo claim.
- Other historical Draft/Inbox submissions outside the ten accepted Build68 areas are not silently deemed merged.
- This IPA is unsigned. Owner-provided signing and physical two-phone BLE/keyboard/performance tests remain necessary.

## CI/release contract

Branch is derived from exact Build68 main `0e4b51e`, includes narrowly scoped PR #243 changes through `e4dbda4`, then a single version-and-instrumentation commit. Reuse Build68 and PR #243 CI evidence for unchanged areas, but **do not bypass exact-head final iOS compile, XCTest, unsigned IPA verification, provenance or main release gate**. Avoid manually re-running the same workflow; let one candidate PR and the required main publishing run complete.

Build identity: marketing 29.2, monotonically increased build 69. No database migration, wire protocol, security entitlement, signing or background-mode change. Preserve existing local user data and back up before installation.
