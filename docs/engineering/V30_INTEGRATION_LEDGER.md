# VeilLink V30 — full Inbox inventory and release-incident ledger

**[INTEGRATION-GOVERNOR]** Snapshot: 2026-11-20. Canonical main `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.

> This is a GitHub-wide source inventory, not certification that each submission has passed semantic review. No V30 IPA is released by this audit.

## Scope actually enumerated
- Complete, non-truncated GitHub `main` tree: **2247 tree entries, 1932 files**.
- All open/closed pull requests retrievable from GitHub: **234** (open 153, merged into some base 66, closed unmerged 15).
- Main `AGENT_INBOX/submissions/`: **36 submission roots**. Newer 2026-11-14 proposals in still-open PR branches are NOT on `main`.
- Detailed snapshot: [V30_INBOX_AUDIT.json](./V30_INBOX_AUDIT.json). The `review_state` field deliberately distinguishes PR state from actual product integration.

## Root cause and non-negotiable release policy
1. Multiple Draft/Inbox proposals were read as if they were merged product features. `main` currently remains Build68; corrected Build69 CI PASS is unmerged.
2. A successful generic Swift/Xcode build is **insufficient** for a user-requested feature. Source inclusion, UI hooks, crypto/transport, compiled binary target, real acceptance and release artifact must be checked separately.
3. Version V30/Build70 must NOT be tagged/published until P0 paths are product-integrated, exact-head CI is green, screen-share extension is embedded and cryptographically authenticated, and device-requiring claims have evidence.
4. Reuse successful Build68/Build69 unchanged tests and do not run repeated candidate workflows during iterative source review. No PR will be opened from this audit branch until local static gates can pass.
5. Never treat an unsupported feature as shipped: show truthful unavailable state until authentication, Apple OS consent and actual transport work.

## Priority acceptance matrix
| Area | Snapshot status | Required closure |
|---|---|---|
| VeilScreen R1/R2.1 | **P0 — missing** | R1 native invitation + R2 ReplayKit Broadcast Upload extension; authenticated ephemeral screen-control and media lane; app-group/keychain signing, viewer, stop; iPhone-to-iPhone video evidence. Exclude incompatible R0 wire. |
| ECLIPSE R17.2 | **P0 — not integrated** | Adapt to R14 baseline without losing robot card, search controls, or user-requested animation removal. Benchmark and UI regression. |
| Gomoku thinking | **P0 — Build69 CI green, not in main** | Carry 9a2a91b; verify 1–10 slider maps to native limits, no wall-clock cutoff still has cancellation/node bounds. |
| FORGE theme | **P1 — style branch only** | Carry d59e2c4 soft round theme and instrument background; verify iPhone appearance and gestures. |
| Blackbox R5 | **P1 — existing source, exact scope unclear** | Check maximum retention, non-content bubble ordering, export/consent/redaction. |
| Chat ordering and keyboard | **P1 — main has source** | Two-device skew, offline reorder, keyboard scroll stability. |
| BLE and Veilopoly | **P1 — main contains several wave fixes** | Physical link/GATT state, queue backpressure, heartbeat, real dual-device transport. |
| Image import/compression | **P1 — main has partial implementation** | Real screenshots + photos and MIME/size, verification and preserved import routes. |
| Galgame and Feature library | **P2 — audit further** | Verify runtime navigation, vendor licensing and project-resource inclusion before release. |

## Explicit open/merged inheritance trap
- PR #237/#239 were merged into intermediate integration bases. That does not independently certify `main`.
- PR #242 reached `main`, but its source acceptance covered only ten enumerated areas.
- PR #243 is the successful corrected Build69 candidate, **not a published main release**.
- PR #232/#236/#234 and other Inbox-only drops are not installed product code.
- The old local zip `VeilLink-126fd...zip` is dated September 2026, not a trustworthy current-head build source.

## Release stop-ship gates
- P0 screen share must pass source wiring **and** compiled extension inclusion, signed entitlement validation and two-device user-consent test.
- No raw screen pixels, chat text or private material may enter debug logs/blackbox; no remote capture without sender's system-level permission.
- No invalid claim of unlimited background BLE delivery or ability to retain all screen text at 240px.
- CI must run on the exact code that will be tagged. Tag/IPA SHA receipt must match a single immutable commit.
- Do not publish V30 with a fake screen-share button just to satisfy a checklist.
