# Agent Inbox Queue

This index is maintained by the Integration Governor.

Agents must not edit queue state directly.

| Submission | Agent | Task | Base main | Status | Batch | Notes |
|---|---|---|---|---|---|---|
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-deeptelemetry-notification-sendability-001/` | `VL-MAINT-EDGE-001` | Swift 6 DeepTelemetry Notification sendability | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `APPLIED` | `2026-10-03` | Narrow callback repair applied in `7825877`; macOS strict-concurrency CI remains required before `VERIFIED`. |
| `AGENT_INBOX/submissions/game-agent/orbit-relay-game-lab/` | `game-agent` | Local Game Mission Contracts + Orbit Relay Game Lab | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `DEFERRED` | `2026-10-03` | Raw one/two-frame UI and synchronous bot search were not accepted; replaced in this batch by separately reviewed real-time SpriteKit games. |
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-appearance-shared-mainactor-002/` | `VL-MAINT-EDGE-001` | Swift 6 Appearance singleton MainActor isolation | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `APPLIED` | `2026-10-03` | Narrow singleton isolation applied in `7825877`; full Apple SDK build remains required before `VERIFIED`. |

Allowed states:

`DROPPED` · `TRIAGED` · `ACCEPTED` · `DEFERRED` · `REJECTED` · `BATCHED` · `APPLIED` · `VERIFIED` · `ARCHIVED`

## Current rule

`TRIAGED` means the submission is structurally valid and has passed Governor intake review.

It does **not** mean the proposal has been accepted for product application.

Only an explicit Integration Governor batch decision may advance a submission to `ACCEPTED` or `BATCHED`.

## V28 Owner-authorized application receipts — 2026-11-07

Owner explicitly authorized unified integration, main merge, V28 and IPA output. This records that one authorized batch; it does not change the Governor identity, default Lane policy, or authority registry.

- Product integration: [PR #161](https://github.com/Righteous1776/VeilLink/pull/161), merged as `d4b58f1391e4286677798f5502ff7ffd815e01fc`.
- Reviewed candidate `19ffb2704e0b960be1726306c331f6febb414276` and merged product have identical tree `355e5afb9ba64c5026a235172148bc66c83c8d3c`.
- Apple CI [42345498509](https://github.com/Righteous1776/VeilLink/actions/runs/42345498509): 237 package tests, 865 host tests, UI smoke, simulator/iPhoneOS Release builds and app/IPA carrier/resource checks PASS.
- `VERIFIED` below means this reconciled source passed those Apple CI gates, **not physical-device RF/headset/power/visual acceptance** and not verbatim application of every old hunk.
- Complete 86-head snapshot/disposition ledger: [V28 intake ledger](../docs/engineering/V28_INBOX_INTAKE_LEDGER_20261107.md). Original proposal branches/records remain audit evidence; this receipt does not falsely claim their inert Inbox PRs were merged.
- Formal Core release run [42347166825](https://github.com/Righteous1776/VeilLink/actions/runs/42347166825) is separate; this receipt records source verification, **not a publication result**.

| Proposal | Status | Applied scope / arbitration |
| --- | --- | --- |
| [#128](https://github.com/Righteous1776/VeilLink/pull/128) | `VERIFIED` | Seat selection / semantic learning roles; malformed patch rewritten and reconciled with #159. |
| [#129](https://github.com/Righteous1776/VeilLink/pull/129) | `VERIFIED` | Owned Files staging/lease cleanup; provider originals preserved. |
| [#130](https://github.com/Righteous1776/VeilLink/pull/130) | `VERIFIED` | Game recovery UI reconciled with #134; requests secure Hello, not refresh-only. |
| [#131](https://github.com/Righteous1776/VeilLink/pull/131) | `VERIFIED` | Fail-closed legal IME commit; no consent-text or signing-policy change. |
| [#132](https://github.com/Righteous1776/VeilLink/pull/132) | `VERIFIED` | Age-gated stale exports cleanup; narrow prefixes and owned-root checks retained. |
| [#133](https://github.com/Righteous1776/VeilLink/pull/133) | `VERIFIED` | Unique export names; no existing export overwritten. |
| [#134](https://github.com/Righteous1776/VeilLink/pull/134) | `VERIFIED` | Secure-session recovery primitive; no protocol/key change. |
| [#136](https://github.com/Righteous1776/VeilLink/pull/136) | `VERIFIED` | Bounded async XCTest wait budget; no product delay added. |
| [#137](https://github.com/Righteous1776/VeilLink/pull/137) | `VERIFIED` | Serial diagnostic logging, lock-backed UI snapshots, telemetry/reconnect damping. |
| [#138](https://github.com/Righteous1776/VeilLink/pull/138) | `VERIFIED` | Startup signposts ONLY; hard BLE image cap NOT accepted, replaced by #156. |
| [#139](https://github.com/Righteous1776/VeilLink/pull/139) | `VERIFIED` | Chat anchor/gesture fixes and insertion-order timestamp ties; no schema change. |
| [#140](https://github.com/Righteous1776/VeilLink/pull/140) | `VERIFIED` | Safe image/text draft imports; no generic binary peer sending. |
| [#141](https://github.com/Righteous1776/VeilLink/pull/141) | `VERIFIED` | Independent native self-play per-move export; Owner clarified this branch. |
| [#142](https://github.com/Righteous1776/VeilLink/pull/142) | `VERIFIED` | Latest-board legal advice + manual opt-in; compact on-demand repair added. |
| [#145](https://github.com/Righteous1776/VeilLink/pull/145) | `VERIFIED` | Deferred full integrity audit; key verification/unchecked-health semantics retained. |
| [#147](https://github.com/Righteous1776/VeilLink/pull/147) | `VERIFIED` | Bounded staging copy and filename policy; no wire capability advertised. |
| [#151](https://github.com/Righteous1776/VeilLink/pull/151) | `VERIFIED` | Reconciled scheduling/audio ownership/coexistence; duplicate test header fixed. |
| [#156](https://github.com/Righteous1776/VeilLink/pull/156) | `VERIFIED` | Nonblocking image soft budget; corrected two Data/byte-count call sites. |
| [#157](https://github.com/Righteous1776/VeilLink/pull/157) | `VERIFIED` | Brightness snapshot coalescing only; no screen-brightness behavior change. |
| [#159](https://github.com/Righteous1776/VeilLink/pull/159) | `VERIFIED` | Durable board recovery reconciled with seats and isolated teaching sessions. |
| [#160](https://github.com/Righteous1776/VeilLink/pull/160) | `VERIFIED` | Original native opponent fallback ONLY; unavailable MP4/GIF not claimed bundled. |

Superseded alternatives: #143 by reconciled #142 UX; #144/#146/#149/#150 by #151; #152–155 by #156; #158 by #159. Existing implementation/source-preservation, planning-only, historical, separate-server and protected protocol/schema dispositions are recorded individually in the full ledger. No unrelated PR is closed and no old protocol/schema proposal is silently promoted.
