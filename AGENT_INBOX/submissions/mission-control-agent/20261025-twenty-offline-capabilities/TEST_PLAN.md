# R1 Validation and staged verification

## Already performed without GitHub Actions
- Exact main Git ref verified: `501ef814a0a9bea41419fe2d9f48315371b30320`.
- Swift source staged under own `FILES/` area, no production tree modification.
- Enumerated 20 unique features; verified 20 analysis switch branches, 20 titles and 20 group labels via source inspection.
- Tool Center `PATCH.diff` context and unified hunk old/new line counts match exact main.
- Ten XCTest methods authored but **not executed**.

## Before code acceptance
1. Apply `PATCH.diff` and copy three `FILES/` to the indicated real source/test paths in an approved integration branch.
2. Confirm Swift 5.9/strict concurrency and Foundation parser semantics, iOS 15 deployment and every identifier.
3. macOS XcodeGen/iOS simulator build, all XCTest (pre-existing tests + new 10).
4. Unit cases for all 20 results on normal/degraded/recovery scenarios; empty peers/edges/events and negative/NaN/Inf input bounds.
5. Path correctness: directed edges, no route, invalid/nonfinite cost, max 1,024 edges, max 256 nodes, first path excludes internal nodes for alternative.
6. Transfer correctness: MTU 23 and 185, zero MTU, checkpoint bigger than total, packet denominator zero, retransmission limits, integer extremes.
7. Privacy & storage: database exists but key inaccessible => blocked; ensure no deletion or new key; no PII leak from diagnostics, no live access in prototype.
8. Device budget: thermal serious/critical, battery fraction out of range, low power and visual special overrides still advisory.
9. UI: segmented scenario changing all 20 results, warnings-only filter, VoiceOver labels, Dynamic Type, iPhone7 narrow display, dark/light switch, tap and ScrollView conflict test.
10. Integration guard: no changes to A9/A10 governor, BLE Wire v4, SQLite v10, Keychain, signing, project version, startup consent, hard gate or IPA workflow.
11. Benchmarks: 20 results with 1,024-edge network below UI hitch budget; no synchronous heavy logs in interactive scrolling.
12. Later real adapter: vendor-provided observation authorization and sampling only, independent review before claiming device data.

## Hard release gate
No `workflow_dispatch`, signed/unsigned IPA, main merge, version bump, or release publication as part of this task. Owner previously required minimizing Actions.
