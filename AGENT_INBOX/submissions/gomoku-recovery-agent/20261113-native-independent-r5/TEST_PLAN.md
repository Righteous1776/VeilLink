# R5 validation and acceptance

## Passed offline

- Strict Swift 6.2.1 Linux compile (`-warnings-as-errors -O`) of pure engine and bridge with ABI-compatible interface mocks.
- Deterministic opening and tactical smoke tests; invalid inputs rejected.
- 212 actual R2 fork-risk positions × 8 dihedral transforms: 1696/1696 root chosen from incumbent R4 safe-set. Verify unique forcing double-win counterattack remains selected.
- 30 private extracted midgames under 160ms; all legal, summary in owner ZIP `evidence/benchmark.txt`.
- Check patch adds only new files: `git apply --check` on clean directory.

## Pending Apple/product

- Xcode project generation, SwiftUI/game controller compilation, native XCTest and UI automation.
- Verify GomokuBot mandatory own-five, opponent-five, R8 win-in-two, R4 fork-safety hard postconditions remain unconditional.
- Verify history/formation training modifies root ordering without overriding proven wins or forcing block; no DB/data migration.
- Perform 500+ paired selfplay matches with identical openings, swapped colors, equal device time and same training seed; compare both win/loss and tactical-error rate. Training-set safety labels cannot substitute for win rate.
- Test VCF proof lines against all immediate defender winning replies and checked five-completion points; do not claim VCT until independently proven.
- Benchmark iPhone 13/iPad latency, memory, cancellation, thermal and background handling, iOS-supported minimum and Swift strict concurrency.
- Compare R5 with previous #186/#187/#190 and integrate only once. Keep old JS as a non-default rollback until full parity acceptance.
- Then and only then delete JS source, JSCore wrapper, bundle references, toggle. Leave app version and release workflow untouched during this Inbox phase.
