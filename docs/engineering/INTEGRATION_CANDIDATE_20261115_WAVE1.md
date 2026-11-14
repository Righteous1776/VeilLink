# VeilLink Wave 1 integration — 2026-11-15

> **Candidate only. Not released. No composite Apple CI or device tests yet.**

Frozen main: `af3d823546c288169d19cb3033a6111977d28bd7` (V29.1 Build 67). Source-truth references:

| Scope | Selected exact source |
|---|---|
| Unified Files import | PR #227 `f433901b88f20e67d94718b980fd0c480c3da6c4` |
| Keyboard + bubble local chronology | PR #230 `8afd957d52bd2ca70c58aa50dd17db96370e8344` |
| Aggressive media/screenshot compression | PR #224 `4a027198477a136685e93f5ecadaeeb841a0d401` |
| BLE and Veilopoly liveness | PR #228 `6497b04b40ce334e60eab042f16f72806a53879b` Inbox `FILES` |
| Global particle removal | PR #229 `21065ab6a3d2ad63e1509bb72314bc67f379c2c5` `PATCH.diff` |
| Game-lobby gesture/scroll repair | PR #235 `3699cdf5018c42885f9635b17dfd771ace6427ac` `PATCH.diff` |

Composition: #224 image status string rebased against #230's ChatView with strict patch matching. #229 deletes global particle overlay, obsolete policy and policy tests only; retains local game effects. #235 replaces eager lobby VStack / zero-distance decorative press gestures without changing button actions. #228 patch candidate BLETransport and source FILES checked exact against frozen main; PR #223/#225 overlap is held for arbitration.

## Unintegrated / blocked

- #222 blackbox R5: app-wide UIKit event instrumentation requires privacy and device verification.
- #233 FORGE theme is canonical to superseded #231; it modifies chat rendering and needs rebase on #230/#224; no blind raw merge.
- #234 ECLIPSE R17.2: hybrid R16/#220 baseline, overlaps #235 lobby; requires separate rebase and game strength regression.
- #232 + #236 VeilScreen R1/R2.1: signed iOS 15 ReplayKit extension, app groups, encrypted BLE media plumbing, verified permissions, two devices; #226 R0 superseded.
- Earlier historical proposals remain untriaged; this candidate does NOT claim that every Inbox item is integrated.

## Release gates

1. Candidate PR macOS/Xcode iOS CI: SwiftUI and ReplayKit compatibility, simulator compile, XCTest, device Release unsigned-IPA carrier validation.
2. Combined regressions across media, chats, BLE, game lobby, import, local persistence. Recheck wire/schema/signing/identity for unintended changes.
3. iPhone and iPad manual acceptance: chat keyboard, clock skew, screenshot readability, Files import, game lobby swipes, BLE two-peer congestion and resumption.
4. Do not merge to main / bump build / tag / publish IPA until green exact-head CI and Owner-approved unresolved scope decisions.

Isolated iOS CI PASSED on #227/#230/#224 individually; this is not proof of combined compatibility. Inbox gates on #228 and #235 PASSED, **not** product iOS build. PR #229 Inbox gate FAILED because its source branch uses disallowed `agent/` prefix; not an iOS compiler failure.
