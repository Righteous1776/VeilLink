# Open risks, partials and collision arbitration

## Not completed
- 2: Persistent Gomoku/Xiangqi separate databases, independent migrations, stats and individual exports. Existing AdaptiveBoardLearning.swift combines both and clips at 1600 positions /40 recent games/512KiB. Do not disable all caps in-place; risk unbounded RAM and corrupting old training packages.
- 3: Live bot/controller wiring and UI “阵法预判” not delivered. An independent in-memory predictor is tested only.
- 8: Guandu standalone solo scene has not passed Apple typecheck or gameplay smoke. Map navigation is staged, not in main.

## High-risk APIs
- `NSFileCoordinator` and security-scoped resources have File Provider lifecycle and re-entrant threading requirements; Linux tests don't compile the Darwin path. Test iCloud placeholder URL, provider-owned virtual file, late async access, cancellation/timeout/cleanup.
- Temporary backups should be protected with Data Protection flags, disk-space checks and no duplicate secret logs before release. `VeilFilesIngress.stage` currently uses FileManager copy; verify sandbox encryption/completeFileProtection on physical iPhone. Ensure staged temp removal after sheet closes AND app restart cleanup.
- Long restore still synchronous on main actor; UI freeze and fail-close rollback regressions possible. Test multiple archive sizes and wrong passwords.
- A10 sample availability: view shows "waiting" rather than stale A9; cannot fabricate a sample if A10 engine stops. UI only, does not alter kernel authority.
- ToolCenter relocation removes direct file SHA link from daily toolbox; Owner diagnostics entry for user-requested hashing still needs final UX arbitration. Background must never scan personal Files without explicit authorization.
- Existing Tactical V2 multiplayer fallback deliberately retained to protect older peer protocol; remove only competing *solo* small map in GameLobby. Standalone scene is a draft and may need API/timing adjustments.

## Competing work
- Historical Codex PRs, Build62 integrated P0 fixes, game rendering R7; direct mutations to main prohibited. Keep the exact main-based diff in one Governor batch; never blanket merge old proposals.
- Monogatari #80/#85 partial GitHub source vs missing binary. Do not treat user-supplied R5 archive as currently available in this runtime. No fake install-success claim.
- No live-lane grant has been issued in repo for this exact eight-point task: all work INBOX_ONLY.

## Separate append-only storage caution
`VeilPerGameLearningJournal.swift` has no fixed global count/file size limit; it trades eviction for increased disk footprint and must be backed by quota-free **user-observable** disk status and reasonable device storage-pressure handling. Its journal import makes a temporary copy and rollback copy, potentially doubling disk usage. The current import writes are not journal-transactional across unexpected process crashes. Governor must perform physical iPhone7 interruption/corruption tests and migrate legacy v1 evidence without ever deleting the original before declaring the learning replacement ready.
