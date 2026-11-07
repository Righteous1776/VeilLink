# VLP-CODEX-P5-001 — live host integration, Apple gate pending

Owner scope override: `P5_OWNER_SCOPE_20261107.md`, coordination #6
issuecomment-6707080274. Before: dev bcf683f; main 2c5b5161027edff097b27fe3323d30f6ca3e430e.
No main merge, PR/IPA-producing CI, workflow dispatch, version/signing or release.

## Actual product route (not a standalone mock)

- GameLobbyView mounts VeilopolyMultiplayerLobby. Explicit invite/accept/decline,
  continue and leave controls; original offline entry remains separate.
- AppModel chains the existing authenticated onControlEventReceived callback
  into VeilopolyMultiplayerBridge. The bridge sends through the EXISTING
  SessionCoordinator.sendControlEvent. No SessionCoordinator, Wire, BLE/LAN,
  identity/key or database source/schema changes.
- Topic `veilopoly.room.v1`, application packet version 1. Authenticated sender
  comes from SessionCoordinator, never the packet's claimed identity. Existing
  signed capability/trust checks and E2EE remain authoritative.
- Public live room configuration -> GameSessionModel's multiplayer constructor
  -> the actual Veilopoly full-screen UI/scene. Not a second game engine.

```text
Guest tap -> proposal -> existing E2EE control -> Host's canonical reducer
Guest replay / logical save <- committed Move + state hash <- Host
Gap or lost request -> resync -> validated host snapshot -> visual catch-up
```

First topology: TWO phones, human host seat 0 + human guest seat 1, existing
AI seats 2/3. No four-device support, host migration, online matchmaking or
competitive anti-cheat claim. Full deterministic game state is visible to peers.
Legacy P3 GameTransport/VeilLinkTransportAdapter remains an unused handoff API;
the real production route above uses the live-room control bridge.

## Safety and lifecycle

- Only host runs automatic movement/resolution, AI and the simulated market
  clock. Guest requests do not mutate local cash/turn/holdings before commit.
- Seat/phase/sequence/hash checks, duplicate rejection and SAME committed log
  prefix on snapshot acceptance. A higher sequence cannot replace different
  already-confirmed history. Host behind guest pauses; no automatic takeover.
- Host waits for matching progress after acceptance/rejoin before driving.
  A pending client request is not considered confirmed by a price tick or
  heartbeat. Periodic resync also repairs a lost proposal at equal hashes.
- Render ACKs never submit guest moves. Guest commits persist immediately while
  presentation catches up; bounded effect buffer, coalesced price-only frames,
  snapshot cancellation does not reroll or repeat purchase/payment.
- Existing A/B persistence uses room ID + host/guest role, separate from solo.
  Identity-scoped atomic resume index stores no keys. Missing host save cannot
  silently restart a known room. Corrupt slots are preserved, not overwritten.
- Explicit Leave deletes only that room's resume INDEX; A/B game records remain.
  Cancelling an unaccepted invite does not delete an old resume index.
- Background/identity change gates the live session. Matching status resumes it
  after foreground recovery; idle invitation timers stop. Real iOS lifecycle
  behavior remains NOT_RUN, despite source-level guards.

## Boundaries / engineering limits

384-byte raw slices, at most 2 MiB logical packet, at most four incomplete
transfers, 300s assembly expiry, 64 completed transfer IDs. Unknown-room packets
are limited to 4 slices, inbound guest commands to 64. Existing BLE 2048-byte
control limit is NOT raised. FIFO sender: 20ms pacing; temporary backpressure
retries up to 50 × 100ms, then visible pause and fresh snapshot recovery. Queue
limit 128 packets, coalescing status/resync/snapshot requests. These are bounded
engineering policies, NOT measured device throughput/energy guarantees.

Send acceptance is not delivery. No new database outbox is introduced; existing
authenticated receipts still work, while live recovery uses heartbeat/hash and
snapshot reconciliation. Very large/congested transfers can time out; >2 MiB
history snapshots fail visibly. Compression/long-history optimization remains
open. Rejected/outdated requests currently recover by snapshot, without a
per-order remote rejection-reason RPC. Normal money rules/paytables unchanged;
live v1 accepts canonical board/cards/default finance terms only.

## Executed evidence

- Initial foundation 8/8 targeted portable cases PASS (5c2ecda).
- Final live-room suites: 15 cases (13 room/fragment + 2 end-to-end), covering
  wrong peer/seat, host-only commands, duplicates, hash/gap/rollback/divergent
  history, invalid snapshot metadata, reordering/interleaving/timeout/bounds,
  identity-scoped resume, 180 scripted moves with dropped commit repair, and
  bank/stock orders without double charging. This is simulation, NOT two phones.
- `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2` → 270 tests,
  0 failures, 34.072s, Linux Swift 6.2.1 → PASS before final doc-only handoff.
- Compile/run `validation/ControlBudget/main.swift` WITH the actual unchanged
  VeilLink/Core/VeilControlEvent.swift and built Net/Engine objects → PASS:
  31 synthetic fragments, observed maximum 1716 bytes, ALL <=2048 bytes,
  codec round-trip. The first 512-byte trial FAILED worst-case slash/base64
  expansion; 384-byte correction passed. Limits were not waived.
- ARM64 iOS15 frontend parse of affected host/UI/test source → PASS, grammar only.
- Added 8 guarded iOS model cases and 2 host XCTest cases → NOT_RUN. Linux excludes
  SwiftUI/SpriteKit and host type-checking. Existing strict Codable warning gate
  remains unresolved, not relabeled PASS.

## Required Apple / two-phone gate (NO IPA output needed)

1. Apple SDK build/type-check and XCTest, without archive/export/packaging.
2. On both phones open game hall after trusted pairing. ONE side invites; other
   accepts; confirm host/guest seats and two AI. Existing old peers may lack this
   topic/capability: no silent fallback, invitation expires after 120s.
3. Roll, move, buy/auction, trade, bank and stock; repeated taps cannot double
   charge, guest cannot control host/AI or run its own price clock. Verify exact
   sequence/hash on both ends, actual animations/card gates/touch and day/night.
4. Disconnect during order, drop commit/last proposal, resume same room; both
   background/force-close/relaunch. Host-behind or differing journal must pause,
   not overwrite confirmed progress. Test corrupt/missing saves and low storage.
5. Verify existing non-Veilopoly control consumers, actual BLE/LAN backpressure,
   frame time/battery and 844×390 / 852×393 / 1180×820. ALL currently NOT_RUN.

NEXT_ONE_TASK: VLP-CODEX-P5-002 — Apple SDK/type-check and two-device acceptance
without IPA; fix failures inside the explicit Owner grant before any integration.
