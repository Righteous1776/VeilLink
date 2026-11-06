# Veilopoly Development Checkpoint — 2026-11-06

**Branch:** `dev/veilopoly` (from `main@ccafebab147e069fbabfff579dbf323b0d54f191`). This is a parallel **development lane**, not the product main branch.

## GitHub source import — COMPLETE for standalone P1–P4

- `1f270948f429af06ec2a1176d57beac1c728adea`: 43 Swift Package text files (Package.swift, README, Engine/AI/Net/UI source, test files, game/model/render specs, validation/license docs).
- `a356d9b9741e25214fac63ee77a376e7b8cfb352`: 26 licensed resource blobs = 14 PNG and 12 WAV (225,915 bytes), plus `Veilopoly/docs/RESOURCE_INTEGRITY.json` with original SHA-256, size and Git blob SHA.
- Earlier branch commits had already introduced this isolated work area, Kimi handoff, permissions and an initial test-file import. The above commits finish the source migration without modifying `main`, transport, Protocol 4, VLGM1 or SQLite V8.
- The newer source baseline is `Veilopoly_P1-P4_Full_Source_20261106.zip`; the five legacy `Veilopoly/INBOX/*` handoff files are superseded by the branch-local `GOVERNANCE.md`, `COLLABORATION.md` and `KIMI_HANDOFF.md` and were not duplicated.

## Verified locally, NOT on GitHub CI / iOS SDK

- `swift build --jobs 2`: **PASS**, Linux Swift 6.2.1.
- `swift test --jobs 2 --skip 'LongSimTests|AutoplayTests'`: **29/29 PASS**.
- `swift test --jobs 2 --filter 'LongSimTests|AutoplayTests'`: **2/2 PASS**.
- Thus **31/31 checks** passed in two local selections against the same imported source state; earlier whole-suite log also reports 31 passed. Linux conditionally excludes SwiftUI/SpriteKit runtime compilation/behavior.
- AI smoke: **500 seeds × max 500 moves** ran without illegal engine moves; **0/500** naturally completed within that short bound. Exploratory **20 seeds × max 6000 moves**: 14 completed, 6 capped. Do NOT claim 500 fully finished games.
- Historical engine coverage evidence: 732/745 lines = **98.26%** for selected Engine+AI tests; no independent coverage run against this exact GitHub branch commit.
- iOS 16 Xcode build, simulator/physical device, FPS, touches, sound and animation ACK **NOT VERIFIED**.

## Next engineering gate

1. Run the checked-in package from the `dev/veilopoly` branch in a clean macOS/Xcode iOS 16 SDK environment and full XCTest inventory.
2. Validate SpriteKit command queue: 1.2s dice, 150ms/tile, skip once and only once, phase ACK, L0–L7, touch and sound.
3. Resolve rules ambiguities in `Veilopoly/docs/SPEC_DECISIONS_REQUIRED.md` with Owner; sample cards and unresolved boundaries remain non-production.
4. Accept Kimi visual K1 package with license/alias/hash and verify mapping without touching Engine logic.
5. After P1–P4 acceptance, request separate authorization for P5 VeilLink adapter / game hall / product release.

**Coordination:** https://github.com/Righteous1776/VeilLink/issues/6

## Post-import P4 UI hardening (source-only)

- Commit `f03583a6252cd1df48c0a7b713d37692bbd84d59` updates `VeilopolyUI/UI.swift` so `animating` is `@Published` (SwiftUI action panel refreshes when the animation queue ACK completes), keeps `configuredHumanCount` through Restart, re-drives an AI-only session after Restart and prioritizes the animation-in-progress panel.
- Local Linux `swift build` and 29 selected non-AI XCTest checks PASS after patch; **the iOS-only SwiftUI source is conditional and did not compile in Linux**, so P4 iOS/Xcode behavior is still unverified.
- Next gate remains macOS/Xcode iOS 16 Simulator and device validation with real SpriteKit frames and ACKs.
