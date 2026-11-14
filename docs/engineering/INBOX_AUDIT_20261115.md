# VeilLink 29.2 Build 68 — Inbox source integration audit (2026-11-15)

## Scope
Compared PRs #221–#236 against current Build68 integration branch code; PR #237–#242 aggregate those submissions. This is **source-level acceptance**, not an Apple-signed dual-device verification. The latest **formal** GitHub Release is still Build67 until the exact candidate passes CI and is merged.

| PR | Subject | Integration verdict |
|---|---|---|
| #221 | R8–R14 paired Gomoku arena | **Not integrated:** validation harness (not a new player-facing mode). No 2,500-pair benchmark performed; performance claims prohibited. |
| #222 | Flight Recorder R5 / touch privacy / bubble chronology | **Integrated in candidate:** structural traces, opt-in touch policy and bounded recorder. Device validation outstanding. |
| #223 | BLE link truth / queue stall probe | **Core integrated plus current repairs:** existing bounded in-place TX probes; this commit fixes PHY/GATT classification and destructive manual recovery, re-arms GATT timeout with in-place notify/discovery instead of a speculative PHY cancel. |
| #224 | Adaptive aggressive BLE image encoder | **Integrated in candidate** (source/tests); no cross-device quality acceptance yet. |
| #225 | Veilopoly game-link and flow | **Partially overlapping earlier #228; newly completed crucial semantics:** silent peer game sync probe, non-destructive GATT retry and noncritical probe-send failure isolation. Do not claim full physical-device verification. |
| #226 | VeilScreen R0 | **Not integrated; superseded protocol v1 prototype** by R1/R2 candidates. |
| #227 | Apple Files unified import | **Integrated in candidate.** |
| #228 | BLE/Veilopoly link stability | **Integrated in candidate;** source-level and CI checks needed. |
| #229 | Remove global particle overlay | **Integrated in candidate.** |
| #230 | Chat keyboard/sequence | **Integrated in candidate.** |
| #231 | Mechanical RF/CPU gauges | **Partially integrated/alternative implementation:** FORGE rotor and health bar available conditionally in theme. Original all-themes mechanical replacement is not delivered. |
| #232 | VeilScreen R1 UI & control | **Not integrated:** cannot promise working invite or viewer without tested transport. |
| #233 | FORGE theme | **Integrated in candidate.** |
| #234 | ECLIPSE R17.2 cockpit | **Partially integrated:** event-based native-search gauges introduced in a recent Build68 candidate commit; full R17 cockpit/refinement conflicts with existing R14/search baseline and is NOT shipped. |
| #235 | Game lobby scroll stutter | **Integrated in candidate.** |
| #236 | VeilScreen R2.1 ReplayKit extension | **Not integrated:** lacks completed signed App Group/keychain, typed E2EE control/media envelopes, iOS background transport acceptance and two-physical-device tests. |

## Release contract

1. **One macOS CI workflow**: source preflight, strict accepted-feature markers, SwiftPM, simulator build, XCTest/UI smoke, iPhoneOS release compilation, compiled-app receipt, unsigned IPA packaging/verification, SHA256 and artifacts.
2. **No "all Inbox integrated" claim:** legacy or research-only Drafts remain pending unless independently accepted and implemented in app source.
3. Exact candidate commit's green CI is required before merging to main, then a new main CI run must pass to publish a versioned Release.
4. Published unsigned IPA requires owner signing. CoreBluetooth behavior, two-device multiplayer, 512 MiB diagnostics retention, media transfer and migration still require on-device checks.
