# Test Plan

## Static checks

- Confirm PATCH.diff applies cleanly to exact base_main_sha.
- Confirm only the three declared new product/test files are introduced.
- Swift strict-concurrency compile scan for Sendable/value-state types.
- Standard repository static preflight after Governor applies an accepted batch.

## Unit tests

1. Initial board has two anchors per side and legal moves for both players.
2. Remote non-adjacent placement is rejected without state mutation.
3. Three-side friendly support converts an enemy node and records capture evidence.
4. Identical legal move sequence yields bit-for-bit Equatable state equality.
5. Bot choice is deterministic from identical state.
6. Bot-selected move is accepted by the same rule engine.
7. Reaching 25 controlled cells immediately resolves majority winner.
8. Wrong actor cannot move out of turn.

## Integration tests

- Apply new core + lab view + tests on a dedicated Governor integration branch.
- XcodeGen/project generation.
- iOS Simulator build.
- Full XCTest inventory.
- Present LatticeClashLabView from a temporary integration-only harness if needed; do not modify permanent navigation solely for testing.

## Negative / failure cases

- index outside 0..<49;
- occupied cell;
- empty cell not adjacent to actor;
- wrong actor;
- move after winner/draw;
- actor with zero remaining nodes;
- opponent with no legal moves (turn retention);
- both sides without legal moves (score resolution);
- capture wave involving multiple simultaneous cells.

## Regression invariants

- Existing game rules remain unchanged.
- MiniGameKind unchanged.
- No protocol/schema/replay format mutation.
- No GameLobby/MiniGameViews/ArcadeGameViews modification.
- No workflow, release, signing, version or build mutation.

## Device / OS coverage

- iOS 15 minimum compatibility build.
- iPhone 7-class device/performance budget.
- Current iPhone portrait layout.
- Dynamic Type and VoiceOver smoke checks.
- Measure synchronous bot-turn latency; target no perceptible stall for normal early/midgame branching.