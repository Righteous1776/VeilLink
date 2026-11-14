# VeilLink 27.2 Build64 — Bugfix Integration Gate R1

Base: `ccafebab147e069fbabfff579dbf323b0d54f191` (verified unchanged on 2026-11-06).
Authority: Owner → VEILLINK-IG-001 → Lane Agents.
Status: INBOX_ONLY triage proposal, **NO PATCH APPLIED TO PRODUCT**.

## Verified candidate inventory
| PR | Scope | Mandatory condition |
| --- | --- | --- |
| #129 | security-scoped import lease lifecycle | preserve provider originals; reconcile #140/#147 |
| #130 | game/chat multitransport recovery | mesh/LAN/BLE/game regression |
| #137 | diagnostic logging and BLE reconnect damping | serial log/strict concurrency/perf |
| #138 | image route cap, startup OS signposts | maximum payload policy, startup trace |
| #139 | chat bottom, game card gestures, SQLite equal-timestamp | real chat scroll and sort |
| #140 | Files image + safe TXT/MD/JSON/CSV to draft | not generic binary send |
| #141 | native Bot self-play detail export | dedicated archive data proof |
| #143 | game assistant move permission UI | preserve manual opt-in & legal revalidation |
| #145 | defer full PRAGMA integrity_check from cold start | database queue contention/memory/Swift6 |
| #146 | reduce BLE duplicate scanning/RSSI when Bluetooth headset active | HFP/A2DP + BLE device pairing |
| #147 | bound Files provider copy; generic filename/MIME policy | E2A only; not network transfer |

## Exact file-level overlaps (9)
- `VeilLink/UI/ConversationViews.swift`: #129 #130 #138 #139 #140.
- `VeilLink/App/AppModel.swift`: #130 #138 #145.
- `VeilLink/App/VeilLinkApp.swift`: #129 #138.
- `VeilLink/UI/MiniGameViews.swift`: #130 #139.
- `VeilLink/Transport/BLETransport.swift`: #137 #146.
- `VeilLink/Core/MediaTransferPolicy.swift`: #138 #147.
- `VeilLinkTests/MediaTransferPolicyTests.swift`: #138 #147.
- `VeilLink/Core/VeilImportedFileAccess.swift`: #140 #147.
- `VeilLinkTests/VeilImportedFileAccessTests.swift`: #140 #147.

## Exact source-hunk intersections (5)
1. `VeilLink/App/VeilLinkApp.swift` #129 lines 14–19 × #138 lines 11–16.
2. `VeilLink/UI/ConversationViews.swift` #129 lines 1087–1093 × #138 lines 1091–1097.
3. `VeilLink/Core/MediaTransferPolicy.swift` #138 lines 16–18 × #147 lines 12–18.
4. `VeilLink/Core/VeilImportedFileAccess.swift` #140 lines 4–12 × #147 lines 4–10.
5. `VeilLink/Core/VeilImportedFileAccess.swift` #140 lines 14–21 × #147 lines 14–21.

## Safe promotion strategy
- **Stage 1 (isolated UI/data)**: #141, #143. The files do not overlap the other 9 proposals. Verify no file export or permission regressions.
- **Stage 2 (transport)**: review and apply #137, then manually rebase #146's BLE coex changes into the same integration branch; do not concatenate conflicting code or relax reconnect protections.
- **Stage 3 (startup and image)**: use #138 signposts/payload route policy, then consider #145 only after cold-start trace + SQL queue-contention study. Keep database key verification fail-closed.
- **Stage 4 (import/UI)**: choose #129 secure staging lease lifecycle as safety base, manually reconcile #140 draft semantics with #147 byte-copy bound; merge #138's image route cap and #139's viewport fixes into `ConversationViews.swift` without discarding either.
- **Stage 5 (multiplayer)**: integrate #130 and #139 `MiniGameViews` behavior together; verify game invites, touch/scroll, resume and 2-device E2EE.
- **Stage 6 (generic binary transfer)**: E2A #147 only stages prerequisite. No shipped PDF/ZIP peer transfer until separate **protocol-change authorization** for new encrypted content kind, signed peer capability negotiation, receiver validation, old-peer refusal and authenticated 2-device tests.
- **Stage 7**: full Apple SDK build, XCTest, UI smoke, protected-surface review, device energy/log checks, approval and rollback checkpoint. Only Governor can merge `main` or release.

## Current validation record
- PR status: 11 Draft PRs, 0 merged, 27 unique target source/test files.
- All 11 proposed unified diff files pass structural hunk count/range audit after corrections.
- #146 and #147 also pass **exact main source hunk-content preflight**.
- This is not a real `git apply --check` on an integration worktree.
- Apple iOS SDK, Xcode, XCTest, two devices, headphones, file transfer: NOT_RUN.
- Current main unchanged, no CI workflow dispatched, no IPA built.

## Stop conditions
Reject any package that overwrites another agent, changes Wire v4/schema/key-management without separate written gate, silently downgrades accessibility or permissions, misreports test status, discards existing archived data, or causes Build64 rollback.
