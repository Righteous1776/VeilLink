# Veilopoly P4 · 本地双槽断电续局 / P3 联机重连检查点

Task: VEILOPOLY-SAVE-RESUME-20261107.
Baseline: dev/veilopoly@0978834e5120973440c9313a3c94c5b354753aa7.
Scope: VEILOPOLY_DEV/** only. No VeilLink main, Protocol 4, SQLite V8, P5 host or IPA changes.

## Owner's acceptance criterion

Single player AND a future linked match must survive normal exit, background eviction and best-effort power interruption. Next launch should present the saved logical state (players, balances, properties, cards, debts, stock portfolio, stock prices/RNG, turn, pending phases), without double-processing a roll, payment, or purchase.

## Implemented: single-player, now connected to the iOS SwiftUI view

- New independent VeilopolyPersistence SwiftPM product/target (Foundation + Engine; no effect on deterministic reducer).
- GameSessionModel automatically resumes the local match keyed by local-human-count slot solo-0..solo-4. A manual in-game Restart explicitly replaces the current run.
- Every successful nonmarket reducer transition is synchronously checkpointed BEFORE visual effects begin, including AI moves and card effects. UI card animation queues are not serialized/replayed; restored SpriteKit nodes snap to the already committed board.
- Continuous stock-tick state is checkpointed at 30-second intervals to avoid a filesystem write every two seconds. Every non-tick user/AI move persists immediately, including all prior ticks. UI inactivity/background exit, view disappearance and explicit Exit force a last checkpoint.
- Restored games in automatic .moveAnim or .tileResolve phase resume via the existing reducer driver. They do not reroll dice; nextSeq, moveLog, decks and RNG counter come directly from stored GameState.
- Location: Application Support/Veilopoly/Sessions (app sandbox, NOT temporary cache).
- Two independent A/B JSON checkpoint generations; write the older slot via Data.write(options: .atomic), reread and verify; select greatest valid revision on startup. Each sealed payload checks GameState's StateDigest plus entire metadata checksum and plausibility (40 tiles, 4 ordered players, move-log sequence, bank bounds and finance ledger). If newest slot is torn/corrupt, fall back to previous valid one.
- If BOTH slots are unreadable, never automatically overwrite a previous match. Display a warning. Only an explicit destructive Restart quarantines unreadable files in Quarantine/ and creates a fresh checkpoint.
- iOS file protection attempts .completeUntilFirstUserAuthentication on saved files. It does not bypass system protection.

## Implemented: multiplayer protocol groundwork, NOT connected to VeilLink P5

- Storage supports separate multiplayerHost and multiplayerGuest slots, keyed by match ID. The same room ID never overwrites solo or opposite-role records.
- Existing P3 GameSnapshot, GameEnvelope, AuthoritativeHost and ReplicaClient remain canonical. New MultiplayerResumeHandshake: guest requests resync with session ID, last sequence and hash; host rejects wrong session and a guest ahead of host; authenticated host can reply with full snapshot; guest verifies same seed, nondecreasing sequence, state hash and log integrity before accepting.
- These are message-level/algorithm-level interfaces ONLY. The current VeilLinkTransportAdapter intentionally throws P5IntegrationRequired.notIntegrated. No actual peer rejoin, BLE/Wi-Fi reconnect, host migration, peer authentication, cloud sync or cross-device storage is claimed. P5 application owner must authenticate transport peers and bind session IDs before this handshake.
- Host authority is required: never allow independent guest disk snapshots to silently diverge and each believe they are the current turn.

## Durability and security caveats

1. Atomic file replacement protects against interrupted writes but cannot guarantee the most recent write physically reaches flash before an instantaneous electrical failure (fsync/platform behavior unproven); fallback may lose the latest not-yet-durable update. Explicit foreground actions are saved synchronously, while high-frequency stock-only changes can be up to ~30 seconds stale after a hard cut.
2. Persistent files disappear on app uninstall unless a future authorized export/backup capability exists.
3. The checksum is for accidental corruption detection, NOT a cryptographic MAC or remote-player authentication. P5 must use authenticated transport.
4. Unfinished SpriteKit actions/card reveal UI are not replayed; the latest logical game snapshot is authoritative.
5. Very long move logs may reach the 48-MiB envelope bound; then saving fails visibly WITHOUT replacing earlier checkpoints. Optimize only with a separately verified game replay/compaction strategy.
6. UI saving is synchronous on the main actor to persist before the next move; Xcode/device latency benchmarking remains required.

## Validation performed

- Local Swift 6.2.1 compiler typechecked GameSaveStore.swift against a minimal Engine compatibility test double, with -warnings-as-errors.
- Local executable smoke: two-slot revision, loading newest, damaged newest → previous version, isolation by game ID and host/guest, both slots damaged → explicit quarantine and clean reset: PASS.
- Added 8 persistence XCTests and 5 network-resume XCTests to the branch. They are not yet executed against the complete remote package or Apple SDK.
- No workflow dispatch, current-head Xcode iOS build, simulator, hard-power-off device test or live two-phone transport test performed.

## Required iOS/P5 gates

1. Xcode SwiftPM clean compile for iOS16+, run all Engine/AI/Net/Persistence/UI XCTest.
2. iPhone test: terminate after roll, bank debit, stock purchase, debt/auction, and card; verify exact nextSeq/hash and no double action.
3. Background kill, forced close, simulated write damage, restart, low disk, first-unlock protection, repeated game restarts; benchmark long move logs.
4. Two-phone session reconnect, both devices power off, host older than guest, divergent hash and host migration. Do not enable automatic multiplayer resume before actual P5 identity/transport integration.
5. Governor gate remains intact: DO NOT merge main, release IPA, change protocol, or dispatch workflows simply because source tests exist.
