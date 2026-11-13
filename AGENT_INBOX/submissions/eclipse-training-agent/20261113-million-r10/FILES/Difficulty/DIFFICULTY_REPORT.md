# ECLIPSE four-tier calibration

All four levels use the same final fitted policy, freestyle rule engine, compulsory win/block checks and root safety checks. Levels allocate different finite depth, width, node and time limits. Persisted raw names `relaxed`, `balanced`, `advanced`, `master` are unchanged. No strength multiplier or Elo claim is made.

| Tier | Depth cap | Width | Node cap | Wall-time ceiling | Forcing depth |
|---|---:|---:|---:|---:|---:|
| relaxed / 轻松 | 1 | 4 | 128 | 80ms | 0 |
| balanced / 均衡 | 2 | 6 | 384 | 180ms | 1 |
| advanced / 进阶 | 3 | 8 | 1000 | 400ms | 2 |
| master / 宗师 | 4 | 12 | 5000 | 950ms | 3 |

The user-selected product budget can lower the wall-time ceiling, preserving the existing full/economy preference. No automatic device-based shutdown or new higher difficulty label is introduced. Unknown future names fall back to master until separately calibrated. Mandatory pre-search safety work is not represented in the counted node cap; observed time is reported independently. The existing V9 extra-tier proposal requires separate arbitration; these four-level results do not validate seven distinct strengths.

## Executed native games

Total **420 complete games**, including 210 color-swapped opening pairs, with **15,083 actual ECLIPSE decisions** after explicitly recorded six-ply presets. Every move was accepted by the actual production `GomokuState.apply`, then a separate Python checker independently reconstructed legal placements and winners. No illegal move, post-terminal move, unfinished cap or corrupted result was found. Both players used the final trained model; these are difficulty tests, not the trained/untrained strength comparison.

| Higher versus lower | Higher W/L/D | Point rate | Paired-bootstrap descriptive 95% interval |
|---|---:|---:|---:|
| balanced / relaxed | 102/77/1 | 56.94% | 50.56%–63.06% |
| advanced / balanced | 40/20/0 | 66.67% | 56.67%–76.67% |
| master / advanced | 102/77/1 | 56.94% | 50.56%–63.33% |

Every adjacent comparison favored the higher tier at the recorded settings and opening distribution. The intervals are descriptive: they do not establish a universal ordering for every position, human skill class, device or opponent. There is no Elo estimate and no strength multiplier.

The initial protocol was 60 games per adjacent pair (30 paired openings). Two pilot intervals included or touched 50%, so an additional 120 independently seeded games were run for relaxed/balanced and advanced/master. Model, rules and all tier limits stayed frozen; no limits were adjusted from match outcomes. The original pilot is retained in `DIFFICULTY_PILOT.json`. This precision extension is not a preregistered multiple-comparison hypothesis test. Seeds were937552101/102/103 initially and937552111/113 for the two extensions.

## Actual CPU cost

| Comparison | Tier | Native decisions | Mean / p95 ms | Mean counted nodes |
|---|---|---:|---:|---:|
| balanced / relaxed | balanced | 3512 | 9.97 / 47.57 | 40.08 |
| balanced / relaxed | relaxed | 3499 | 8.12 / 37.89 | 5.44 |
| advanced / balanced | advanced | 975 | 29.32 / 80.68 | 191.48 |
| advanced / balanced | balanced | 965 | 17.64 / 56.27 | 38.71 |
| master / advanced | master | 3072 | 42.91 / 120.09 | 1451.21 |
| master / advanced | advanced | 3060 | 9.86 / 23.14 | 186.20 |

Observed CPU timings are Linux measurements and include different concurrent loads across pilot and extension; they are not iPhone latency or thermal guarantees. Comparison-specific timing is retained rather than averaging across different opponents/positions.

## Reproduction

Compile the final `VeilGomokuUnifiedSearch.swift`, final `EclipseTrainedOrdering.swift`, `FILES/Arena/NativeGomokuRules.swift` and `FILES/Arena/EclipseArena.swift` with Swift6.2.1, `-O -j 1 -swift-version 6 -warnings-as-errors`. Run `calibrate_difficulty.py --binary <arena> --output <external-work-dir> --auditor <FILES/Arena/audit_arena.py> --games 60 --seed 937552101`. The additional command budgets and seeds are recorded below. Never overwrite an existing raw arena file. Complete replay logs live outside the Inbox at `/workspace/scratch/eclipse-difficulty/calibration-v1/` and `/workspace/scratch/eclipse-difficulty/confirmation-v1/`; SHA-256 values are in `DIFFICULTY_METRICS.json`.

Confirmation balanced versus relaxed: challenger depth2/width6/nodes384/time180/forcing1; baseline trained depth1/width4/nodes128/time80/forcing0; games120,seed937552111. Confirmation master versus advanced: challenger depth4/width12/nodes5000/time950/forcing3; baseline trained depth3/width8/nodes1000/time400/forcing2; games120,seed937552113. `aggregate_difficulty.py` combines raw logs with seed-aware paired identity.
