# ECLIPSE R12 tests and promotion gate

## Executed
- Swift 6.2.1 optimized strict compilation of new `EclipseHorizonQuiescenceR12.swift` with standalone `TESTS/main.swift`: PASS (1,607 assertions).
- Targeted exact own-five, distinct double opponent completion, unique forced block with NO fabricated mate, quiet/invalid inputs, 32 symmetry checks, 500 deterministic seeded positions with independent move-application brute-force comparator, and synthetic directional four-in-row probes.
- 3 published Codex evaluation positions replayed: `final-compact-a` pair 0 forced blocks at 188 and 184, and `final-time50` pair 0 own immediate win at 124. These are DEVELOPMENT regression cases once used here.
- Independent read-only audit of all 920 Codex arena JSONL game records: 34,257 placed stones including 5,520 opening preset stones; 28,737 decision records, 0 illegal/turn mismatches, 0 missed own-five and 0 missed unique immediate blocks. Results are about the existing Codex root engine, NOT R12 win-rate gains.
- GitHub staged source full kernel and two-hunk overlay preimage anchored to Codex commit d93e579; product files remain unmodified.

## Must run before any enforced use (NOT_RUN)
1. Apply Codex PR #209 on integration lane; `git apply --check PATCH.diff` after exact Codex source and before any R11/V9 conflicting overwrites. Ensure new Swift file picked up by Xcode project source path.
2. Swift 6 Xcode simulator + iPhone device compile using FULL 48-tree model and R12 enabled/disabled, run native `EclipseHorizonR12Tests.swift`.
3. For 500+ fresh, opening-paired and color-swapped complete games at equal actual wall clock AND at equal node count, report W/L/D/95% paired CI, decision depth and leaf-extension counts.
4. CPU budget P50/P95/P99, 4G/6G memory, device thermals/battery on iPhone 13 and iPad Air 4; no soft time target misrepresented as hard deadline.
5. Fuzz tests against real `GomokuState.apply` and all seven V9 difficulty raw names; protect ECLIPSE R9 no-live-hints.
6. Governor signs overlap and promotion decision. No automatic workflow dispatch or release.
