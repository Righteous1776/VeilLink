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
