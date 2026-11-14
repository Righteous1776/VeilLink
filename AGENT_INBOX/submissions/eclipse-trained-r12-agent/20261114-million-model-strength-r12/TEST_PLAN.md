# R12 deterministic tests and release gates

LOCAL_EXECUTED:
- `swiftc -O -swift-version 6 -warnings-as-errors` two separate Swift6 modules PASS, no UIKit dependencies.
- `EclipseR12OrderingMemo`: 4,240 asserts PASS; all selected model-surrogate scores remain bit-identical under 6 repeated depths, two sides, 225 squares, 512 different board hashes and deliberate bucket collisions. This is surrogate-only; full 48-tree runtime unbenchmarked.
- `EclipseR12LeafThreats`: 270 asserts PASS; 80 D4-transformed Codex public evaluation positions plus 10 synthetic cases, each checked for exact distinct completion squares by independent 225-square legal placement oracle.
- 5 published Codex baseline tactical incidents × 8 board symmetries × 3 checks, 120 strict R11 replay assertions PASS. No private Owner historical games committed.
- 10 exact target-source unified diff hunks match Codex commit d93e579 source preimages; this does not establish iOS compile.

NEXT_GATES:
- Product compile Swift6/Xcode and Apple target test; compile all relevant modules together (not yet run).
- Run precise frozen mode flags-off parity on Codex PR209's 9,024 model scores, 82 tactic tests, 50 kernel baseline tests and 920 historical matches (do not retrain/tune on these).
- Run *fresh* matched-opening tournaments vs frozen PR209 with equal wall-clock and node-mode budgets, distinct unseen openings and color reversal; count draws/unfinished correctly and report paired CI. No 6x playing-strength promise.
- Real device CPU/time energy + thermal and search pause/cancel; session-safe no-live-hints.
- Stage selected batch as Governor review integration; no direct main or release.
