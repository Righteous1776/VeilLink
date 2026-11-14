# Five-Night / Global Coverage Verification Gates

## Already executed
- [x] Current main `af3d823546c288169d19cb3033a6111977d28bd7`, Issue #6 and governance read.
- [x] All unified diff hunks replayed against exact current main.
- [x] Existing PR branch verified as Inbox-only, no product source edits.
- [ ] macOS simulator compile and full XCTest — NOT_RUN.
- [ ] Two-device BLE/LAN/Relay / owner UI on physical device — NOT_RUN.
- [ ] 5-night 15-hour workload and archive integrity — NOT_RUN.

## Proposed test additions
1. Configured retention: 512 MiB, 6,000 window; cold-reload ordering; older 23rd rotation failure fixture; pre-consent 512 persistence.
2. Bubble event metadata is a fixed allowlist, with no message body, draft, search phrase or stable ID. Validate ordering under reload, prepend old pages, deletions, searching, game sessions and multiple chats.
3. Feature inventory export: source registry `alpha,beta`, only `alpha` checkpoint observed -> `beta` labeled unobserved, not “no coverage”; test is included in proposed patch.
4. Export manifest reports exact first/last timestamps, `retainedTimeSpanHours` and disk rotation evictions; verify eviction counter survives restart and clear resets it. Recheck SHA-256.
5. Fill log with >=512 MiB representative volume, interrupt writes, simulate low disk / locked data and force export; preserve already confirmed records on failed writes.
6. Playback five actual nightly sessions with real feature usage, including transport reconnects, media, Voice, Agent/A9/A10, games, recovery and storage. Compare expected module checklist to observed `moduleCheckpointCounts`. Do NOT call gaps covered.
7. Privacy sentinel corpus in chat message, text input, secrets and filenames; inspect every staged JSONL/manifest/ZIP entry for unintended payload.
8. Owner “enable all” is explicit, visible and reversible; verify no new entitlements, background recording or cross-app reading.
9. Profile CPU, RAM, I/O, battery/thermal, disk consumption and single ZIP staging on iPhone/iPad; require owner-approved warning for insufficient space.
10. After milestones A–G (compression/age retention/priority/export splits/coverage CI) repeat 5-night verification and require no unaccounted event drops.

## Release gate
Governor-managed cherry-pick or rewritten integration branch only; compare existing diagnostics PRs first. XCTest, iPhoneOS Release, unsigned IPA content inspection and separate real-device privacy/export validation required before merge. Never claim tests or IPA that were not actually run.


## R3 critical module-coverage tests — not yet run

- [ ] Local AI game matrix: run each of seven `MiniGameKind` cases and assert an accepted turn produces an app-owned `game.<kind>` checkpoint; verify match restart, finish, rejected action, AI cancellation and persistence failure do not yield misleading success events.
- [ ] Gomoku/ECLIPSE: record valid human/AI cells and ply ordering, budget multiplier at all seven tiers, AI search start/end and realistic duration, native training batch counts, failure handling; compare log chronology with actual game archive without copying the archive to logs.
- [ ] BLE hardware: induce first connection, central/peripheral GATT readiness, disconnect, repeated reconnection, handshake timeout, queue pressure in BOTH admission directions and background resumption; compare event IDs to actual connection state snapshots. Confirm no encrypted/plaintext packet data is included.
- [ ] Multiplayer Veilopoly: two signed test devices; invite/accept/decline, send errors, queue cap, packet fragment counts, host-authoritative reducer updates, reconnect/resync, restore on relaunch, identity-change suspend, room leave; assert no old publisher observer remains subscribed.
- [ ] Offline Veilopoly & finance/auction/stock/AI: mark `NOT_INSTRUMENTED` until real engine hooks exist; no user-facing full-coverage claim.
- [ ] Arcade/story routes: 14 entry signals; require standalone test for scene update, frame stall, pause/resume, scoring, save/error, engine shutdown BEFORE classifying a game as `STATE_MACHINE` or `DEEP_DIAGNOSTICS`.
- [ ] Privacy sentinel: message content, contact name, BLE payload bytes, Monopoly card text, game save file contents and access tokens must not appear in ZIP; numeric move coordinates and transmission byte counts are allowed.
- [ ] Load test: 15-hour example scenario with simulated BLE retry storm, native Gomoku training and a realtime game; observe true retention span, overwritten segments, queue throttling, battery/thermal and ZIP size. No claim five nights unless observed.

Compiled iOS/XCTest status: **NOT_RUN**. Patch context replay is NOT compile/test certification.
