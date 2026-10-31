# S1 training report — executed native Gomoku self-play

## Provenance

Target: PR #114 head `14f2740620c0a73874df1588f146ad0f9a67589c`; main baseline `e093e7fb7ab0eb9821a014b753ab2bdc27613ec8`; Swift image `swift:6.2.1-jammy` digest `sha256:6e33c70a59180c9b518f67728538312975cb3891177d20215cd2e31bdfe70791`.

The compiled Bot source SHA-256 is `56c905d35e27fa775906643fe16b1f402249d787bfb2e5aa5abd826aadd1e042`. The matching state source SHA-256 is `2bd7e04f6622845f50923a0363255e82a69ebb0efba19ccb78efe271694a5916`.

## Existing 2,000-game evidence reproduced

`GomokuNativeTrainingSeed.json` SHA-256 `9f7ddf5c847d6beb972c5a98ad83daa66df189f82171988ac1da68d6142188e0` and FNV1a64 `29e9808a4a69618b` passed independent replay. Results: 2,000 complete, 93,530 total plies, 2,000 presets, 91,530 Bot decisions, 1,102 host wins / 860 guest wins / 38 draws, 236 exact sequences / 228 symmetry sequences, 10,710 exact positions / 10,310 symmetry positions, 0 invalid.

## S1 new native execution

| Metric | Result |
|---|---:|
| New complete games | 1,000 |
| New Bot decisions | 51,292 |
| Preset first stones | 1,000 |
| Invalid / unfinished | 0 / 0 |
| Host wins / guest wins / draws | 533 / 462 / 5 |
| Exact sequences / symmetry sequences | 254 / 186 |
| Exact positions / symmetry positions | 12,532 / 7,373 |
| Opening intersections | 225 / 225 |
| Formation pairs | 36 / 36 |
| Wall time | 84,004 ms |

The raw shard SHA-256 is `2953b457c7992dbeb2e72af55ba99779a8e4dba071b34c5385c70b3b63a4a2d9`; its independent audit SHA-256 is `6a78e5ccee01cb7ac2ca463123b828165aa8f420d1683b8e39453dbe362adfc0`.

## Bagua use / break / innovate result

The external JSON export `s1-1000-bagua-analysis.json` (`cf8f75087a8c7e110a2ce609508cb33dbcd536bae93a6c6400d5710b8b7dcdf1`) contains movement signatures, per-colour outcomes, terminal formations and Bagua loss cases. It is the export mechanism for analysis and later lesson generation.

Current evidence does **not** support an autonomous improved Bagua policy. Colour-swapped testing gives 199.0/400 points (49.75%, 95% Wilson [44.88%, 54.63%]) for the current Bagua preference against off. The candidate is quarantined from default use. Its white-side losses and terminal signature records are the concrete counterplay corpus for S2.

## App impact

No game was written into `AdaptiveBoardLearningStore`, imported into the App, written over player history, or turned into a model/default setting. App-trained count change: **0**.
