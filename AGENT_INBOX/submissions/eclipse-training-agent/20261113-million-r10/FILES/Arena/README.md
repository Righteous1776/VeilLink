# Native ECLIPSE arena and independent audit

`EclipseArena.swift` calls the actual proposed ECLIPSE `VeilGomokuUnifiedSearch.decide` for every post-opening move. `NativeGomokuRules.swift` contains verbatim `MiniGamePlayer` and `GomokuState` blocks from `main@eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`; the arena applies every preset and decision through `GomokuState.apply`. `audit_arena.py` separately replays the full move journal using an independently written five-in-row detector and validates winner, role, journal and color-pair consistency.

Each pair uses the same six explicitly preset, legal central opening plies and reverses which color uses the trained policy. Presets are never counted as actual native decisions. Complete games, draws, capped attempts and illegal decisions are reported separately. The model changes candidate ordering in the native tree; turning `trainedPolicy` off uses the original PR193 adjacency ordering. No app learning count or user database is modified.

The final evaluation candidate is the strict D4 board/action-deduplicated model, SHA-256 `f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe`. Earlier 200-game compact and 200-game deeper runs used a superseded model containing 5,204 symmetry-equivalent candidate records and are retained only as pilot evidence outside this package. Their outcomes do not enter the final results.

Final seeds were fixed before their corresponding runs, after the strict refit and without tuning the candidate to arena outcomes:

| Run | Seed | Games | Depth | Width | Counted node cap | Wall ceiling | Forcing depth |
|---|---:|---:|---:|---:|---:|---:|---:|
| Compact | 937551941 | 200 | 3 | 8 | 1,000 | 2,000 ms | 0 |
| Deeper | 937551943 | 200 | 4 | 12 | 5,000 | 2,000 ms | 3 |
| Same wall target | 937551947 | 100 | 6 | 12 | 1,000,000 | 50 ms | 3 |

Both sides use identical search limits within a model A/B game. Mandatory root safety scans are not included in the kernel's node counter, and can exceed its nominal wall ceiling. CPU wall times are Linux observations under the recorded environment load, not iPhone performance measurements. Pair-cluster bootstrap intervals are primary; the per-game Wilson interval is explicitly descriptive because games within an opening pair are dependent. These matches do not establish cross-engine Elo, full Master strength or a multiplicative increase in playing ability.

Final compact result: 114 trained wins, 85 original wins and one draw; trained points 57.25%, 95% pair-bootstrap interval [51.25%, 63.0%]. Final deeper result: 110 trained wins, 89 original wins and one draw; trained points 55.25%, interval [49.5%, 61.0%]. The deeper interval includes equal strength. The separate same-wall-target run, started after all other CPU-intensive arenas completed, gives 59 trained wins, 40 original wins and one draw: 59.5%, interval [52.5%, 66.5%]. Learned/original p95 decision times are 50.10/50.03 ms; mandatory root safety work yields maxima 65.29/68.57 ms. All 500 games replay legally, with no caps; they contain 13,654 genuine post-preset native decisions. This supports improvement at the tested compact and wall-target budgets and demonstrates actual parameter effect, but does not establish a large or robust improvement at deeper search. Intervals describe each predeclared test separately and do not include a multiple-comparison adjustment.

On 100 distinct held-out boards, identical-budget native decisions change on 55 boards with learning enabled. The 82 tactical checks pass, and disabling learning exactly preserves the original kernel's move, score, nodes, depth, rule and variation on 50 deterministic random legal midgames. Full details and immutable source digests are in `RESULTS/`.

## Reproduction

From this `Arena` directory, with Swift 6.2.1 available:

```sh
swiftc -O -j 1 ../Native/VeilGomokuUnifiedSearch.swift ../Training/EclipseTrainedOrdering.swift NativeGomokuRules.swift EclipseArena.swift -o /tmp/eclipse-arena
/tmp/eclipse-arena --games 200 --seed 937551941 --depth 3 --width 8 --nodes 1000 --milliseconds 2000 --forcing-depth 0 --output /tmp/eclipse-compact.jsonl
python audit_arena.py /tmp/eclipse-compact.jsonl --output /tmp/eclipse-compact-report.json
/tmp/eclipse-arena --games 200 --seed 937551943 --depth 4 --width 12 --nodes 5000 --milliseconds 2000 --forcing-depth 3 --output /tmp/eclipse-deeper.jsonl
python audit_arena.py /tmp/eclipse-deeper.jsonl --output /tmp/eclipse-deeper-report.json
/tmp/eclipse-arena --games 100 --seed 937551947 --depth 6 --width 12 --nodes 1000000 --milliseconds 50 --forcing-depth 3 --output /tmp/eclipse-time50.jsonl
python audit_arena.py /tmp/eclipse-time50.jsonl --output /tmp/eclipse-time50-report.json
swiftc -O -j 1 ../Native/VeilGomokuUnifiedSearch.swift ../Training/EclipseTrainedOrdering.swift EclipseTactics.swift -o /tmp/eclipse-tactics
/tmp/eclipse-tactics
```

The arena refuses to overwrite a pre-existing evidence file. `--pair-offset` permits independent shards while retaining exact paired presets. For difficulty comparisons, `--baseline-trained` enables the same model for the opposing role, with independent `--baseline-depth`, `--baseline-width`, `--baseline-nodes`, `--baseline-milliseconds` and `--baseline-forcing-depth` overrides. The historical output names `trainedSide` / `trainedWon` denote the designated challenger role in those comparisons; the per-decision `trained` field records whether learned inference actually ran.

`EclipseTactics.swift` verifies 82 immediate-win, mandatory-block, pure fork-defense, winning-counterattack and expired-budget fallback cases across all eight board symmetries, with learning both off and on. The pure-defense fixture uses `[0,2,4,30,32]` as in production XCTest; the obsolete `[0,2,4,6,8]` fixture admits a valid winning counterattack at 3/5 and is tested separately.

`EclipseBaselineParity.swift` compares the original PR193 kernel (mechanically renamed `BaselineGomokuUnifiedSearch` in a separate runtime source) with the proposed kernel's `trainedPolicy: false` on 50 deterministic random legal midgames. It requires identical move, integer score, counted nodes, completed depth, rule and variation. This protects the baseline from accidental changes during integration.
