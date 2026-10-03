# Integration Batch 2026-10-03

Governor: `VEILLINK-IG-001`

Owner authorization: the repository owner explicitly requested a unified integration,
maintenance hardening, feature expansion, packaging and upgrade after parallel-agent work.

Baseline: `5cdca5b3d4461ec5bcdfe3a23fea3ec55c396a91`

## Freeze and boundaries

- Integrate on `codex/inbox-integration`; do not write directly to `main`.
- Do not change Protocol 4, VLGM1 v1, SQLite Schema V8, identity/key contracts or
  signing material in this batch.
- Preserve the published `26.10 (56)` release until all product gates pass. Version
  and build changes belong to the final release commit only.
- Parallel implementation lanes use isolated worktrees and may not push, merge or
  dispatch workflows. The Governor reviews and cherry-picks each local commit.

## Intake decisions

| Candidate | Initial decision | Integration treatment |
|---|---|---|
| DeepTelemetry sendability | ACCEPT / REVIEW | Apply only if current callback queue invariant still holds; run strict-concurrency CI. |
| Appearance shared MainActor | ACCEPT / REVIEW | Apply with a full consumer audit; do not weaken actor isolation to silence errors. |
| Conversation effective-limit snapshot | ACCEPT / REVIEW | Apply immutable capture repair and focused pagination regression tests. |
| Local-tool complexity engine | ACCEPT / REWRITE | Keep additive pure APIs and tests; UI exposure is a separate decision. |
| Skeuomorphic performance budget | ACCEPT / REWRITE | Use as an explicit render contract; retain Reduce Motion and authenticated God override semantics. |
| Orbit Relay proposal | REWRITE | Do not apply the one/two-frame UI or synchronous main-thread bot loop verbatim. Salvage rules/tests only after real-time presentation review. |
| Lattice Clash proposal | REWRITE | Do not apply synchronous main-thread bot/UI transition verbatim. Defer product entry until animation and background search are real. |
| PR #10 restoration evidence | DEFER | Read-only evidence; quarantined history is not a merge source. Select features individually against current main. |
| Local realtime arcade/live-tool candidates (`9d5a9b6`) | ACCEPT / REWRITE | Repair compile blockers, lifecycle/resource arbitration, tests and entry points before integration. |

## Mandatory product repairs

1. Quarantine the historical Build 55 workflow's direct-main mutation path.
2. Repair BLE low-ATT admission, dual-role stall tracking and control-capacity guarantees.
3. Make LAN refresh non-destructive and restart failed listener/browser paths.
4. Repair PTT tail ordering, page-independent receive lifecycle, 40 ms UI truth and
   chat regressions (voice quote label and assistant entry).
5. Replace black-box false positives with acknowledged UI actions, real readiness
   waits and explicit skipped/failed states.
6. Connect A9/A10 governance outputs to observable runtime contracts and include LAN
   in transport health; do not claim physical chip execution.
7. Add professional local real-time game/tool surfaces without replacing the existing
   encrypted game and Tool Center inventory.

## Required gates

- Inbox overlap and protected-surface review
- recovery lineage and Core source isolation
- static preflight and XcodeGen generation
- iOS Simulator build on the minimum supported configuration
- full XCTest plus new focused regression tests
- unsigned `iphoneos` Release build and Core carrier verifier
- no version/build drift before release commit
- physical-device limitations explicitly recorded; no RF/thermal claim from simulator data

## Applied integration result

| Area | Integration commit | Result |
|---|---|---|
| Archived Build 55 publisher | `7b06962` | Direct-main mutation removed; workflow is read-only validation only. |
| Chat and PTT ordering | `badf6cb`, `3298fdc` | Tail/end FIFO ordering, truthful 40 ms copy, restored assistant entry, voice quote repair, and page-independent foreground receive routing. |
| LAN Turbo | `2a4bd46` | Healthy refresh preserves links and queues; listener/browser have bounded independent recovery; decoder uses a read cursor. |
| BLE transport | `894817b` | Direction-specific stall clocks, control reserve, direct packet encoding, and reachable SE1/ATT20 attachment admission without a wire change. |
| Black-box stress | `e54f952` | Mounted consumers must acknowledge UI work; A9/A10 samples must advance; excluded runtime work is skipped rather than falsely passed. |
| Inbox maintenance | `7825877` | Narrow Swift concurrency repairs, immutable conversation paging capture, visible tool analysis, and an enforced render budget. |
| Real-time features | `f75ab26` | Three SpriteKit games, four hardware-backed live tools, navigation entries, lifecycle handling, deterministic model tests, and God Mode high-refresh override. |
| A9/A10 governance | `fa60794` | LAN readiness, recovery and queued bytes are included in the shared runtime health input. |

Linux-side lineage, protected-source, repository hygiene, resource, Python/shell and
focused static checks passed with 215 product Swift files and 78 XCTest files. The
standard preflight reaches Swift parsing and then stops because this environment has
no Apple `xcrun`; simulator, XCTest and unsigned device build remain release gates.
