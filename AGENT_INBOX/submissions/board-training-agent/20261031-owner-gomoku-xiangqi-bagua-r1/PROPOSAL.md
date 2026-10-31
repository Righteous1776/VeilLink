# Board learning 27.1: train from real evidence without wiping local history

## Actual completed offline training pass
- Ingested both attached game exports, verified existing canonical FNV-1a64 payload checksums, preserved original JSON as `FILES/VeilLink/Resources/`.
- Gomoku: 700 black host moves and 672 within-game consecutive move displacements. Knight geometry (1,2)/(2,1) occurred 196 times (29.1667%). 21/28 openings begin index 112 (board center). 18 unfinished games require outcome caution.
- Xiangqi retains independent 178-state evidence and 4 game records; no cross-game moves.
- Produces Bagua training profile `FILES/Training/bagua_training_profile_v1.json`. This is an explainable pattern classifier, **not** neural-network weight training or evidence of an unbeatable strategy.

## Proposed product integration
1. Governor copies 2 original JSON seed files from FILES/ to the stated `VeilLink/Resources/` paths. XcodeGen must confirm they are app-bundle resources.
2. Apply `PATCH.diff`: additive `mergeReviewedPackage(from:)` after schema/FNV validation, dedup by game/result/timestamp/moves, preserve pre-existing actions and existing game statistics; maintain corruption recovery fence and atomic disk write rollback.
3. Switch developer-only training import to non-destructive merge, resolving current UI claim "merged" vs actual full replacement.
4. Add developer-gated **Load built-in Owner training** button that does not depend on the broken Files picker. It uses Bundle.main instead of outside URLs but still respects Owner Mode, app lock and training gate.
5. Add pure geometric `VeilBaguaFormation` recognizer and coach lesson. The bot's existing sampled preferences/sequence prediction pipeline consumes the merged real game data; no override of forced win/block rules.
6. No automatic silent override of users' private training databases, no added network traffic, no schema or protocol change.

## Research boundaries
The “single predetermined cracking point” is Owner's conjecture. The 28 games cannot establish such uniqueness, nor establish a general win-rate benefit. Train multi-point opponent counterexamples on-device later; prioritize tactical search over style.

## Integration order
First Governor reviews P0 Files PR #109 and existing #92–#95. Then verify this additive seed insertion on isolated branch, run full XCTest/unsigned Release compile, and only later consider release.
