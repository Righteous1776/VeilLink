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

## P4 landscape-fullscreen / capsule UI checkpoint — 2026-11-06

- Commit `a9cf562dad13457a42d42bbe47f802cf9af592da` adds true landscape screen composition: full-screen SwiftUI cover, iOS 16 UIWindowScene orientation request + best-effort restore, 40-tile board non-scrollable left with independent action sidebar right, and portrait-orientation failure explanation.
- Right-top two-segment capsule is SwiftUI vector (no additional PNG): `•••` More, circular Exit; 46×44pt independent targets; More opens Restart/Game Info, Exit confirms and calls provided exit/dismiss.
- New `VeilopolyLandscapeLayout` pure layout constants, `VeilopolyUITests/LandscapeLayoutTests.swift` and `Package.swift` test target.
- Source contract and future P5 host requirements: `Veilopoly/docs/LANDSCAPE_PRESENTATION.md`.
- Existing resource inventory and Kimi pending-asset audit: `Veilopoly/docs/ASSET_GAP_REGISTER.md`. Kimi already owns some unsubmitted modeling; those items remain **PENDING_EXISTING_WORK_REVIEW**, NOT confirmed missing.
- Linux local `swift build --jobs 2` and selected `swift test --jobs 2 --skip 'AutoplayTests|LongSimTests'` **PASS (34 tests, 0 failures)**; `LandscapeLayoutTests` alone **5/5 PASS**. SwiftUI/UIKit iOS code compiled conditionally out on Linux; iOS SDK, physical rotation, safe area, capsule, SpriteKit and host app P5 still **UNVERIFIED**.
- P5 real VeilLink entry and host Info.plist/navigation orientation support remain outside this branch's write authorization. Do not claim orientation rotates actual VeilLink build before P5 integration.

## Kimi K1 parallel visual admission + P4 follow-up (2026-11-06)

- Received and verified Owner-supplied `Veilopoly_Kimi_K1_v1.zip`. ZIP CRC and its 22 SHA256SUMS entries all passed. Staged **22 original source/preview/asset files** extracted (no opaque ZIP) under `INCOMING_ASSETS/KIMI_K1_v1/`; imported **3 optional PNG runtime resources**, corrected atlas XML metadata, and converted buildClick OGG to 22,050 Hz PCM WAV. Parent staging commit: `38f8c90bb2b60b39dbf4905d305937390033712e`.
- Kimi 9/9 new asset SHA256 claims match payload, but two **existing** manifest entries differ from actual repo hash: `die4.png`, `mortgage.wav`. Exact evidence in `Veilopoly/docs/KIMI_K1_INTEGRATION_REVIEW.md`; original Kimi manifest remains untouched. Kimi needs to correct these metadata entries in K2 (no need to re-create binaries).
- K1 `LAYOUT_SPEC.md` uses a portrait iPhone main screen; **superseded** by Owner's full-screen landscape requirement. K2 priorities and missing 2.5D outputs listed in `Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md`.
- SwiftUI landscape fullscreen + WeChat-style More/Exit capsule were already implemented in the isolated development UI (commit `a9cf562dad13457a42d42bbe47f802cf9af592da`). K1 follow-up now uses supplied dice sheet atlas with six pure-coordinate UV lookups and existing-six-PNG fallback; plays converted `buildClick.wav`; added 3 portable resource/atlas tests, in code commit `1ecaf8b09af5d0a1c900453b9eae4bbe414f1e8b`.
- **Linux Swift 6.2.1:** `swift build --jobs 2` PASS; `swift test --skip 'LongSimTests|AutoplayTests'` **37/37 PASS**; `swift test --filter 'LongSimTests|AutoplayTests'` **2/2 PASS** before the final resource-existence assertion was added (engine/AI unchanged); K1 three new tests also PASS after that addition. All claims relate to local Linux, not branch CI or Apple SDK. AI 500 seeds remain bounded, not 500 completed games.
- **Unverified and gated:** iOS 16 SpriteKit/UIKit/SwiftUI target compile, scene rotation / true full-screen, active capsule 44×44pt hit zones, device safe area, animation ACK, real touch/audio, P5 hosting, main merge and IPA. No product transport, Protocol 4, VLGM1 or SQLite V8 changes.
