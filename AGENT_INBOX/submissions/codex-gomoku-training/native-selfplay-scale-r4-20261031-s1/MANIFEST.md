# Manifest — native Gomoku self-play scale R4 / S1

- agent_id: `codex-gomoku-training`
- task_id: `native-selfplay-scale-r4-20261031-s1`
- status: `DROPPED`
- lane: `INBOX_ONLY`
- base_main_sha: `e093e7fb7ab0eb9821a014b753ab2bdc27613ec8`
- product target: Draft PR #114, head `14f2740620c0a73874df1588f146ad0f9a67589c`
- product native source revision claimed by bundled seed: `bc919b454379841180fb8698a9e0addec87e7af0`
- product-tree mutation in this branch: **none**
- release / IPA / schema / user-data mutation: **none**

## Actual S1 delivery

1. Independently replayed the existing PR #114 2,000-game bundle: all records valid.
2. Compiled the unmodified PR #114 `GomokuBot.swift` and `GomokuFormationLearning.swift` with a Foundation-only compatibility shell, then ran **1,000 new complete Bot-vs-Bot games**.
3. Every new game contains one separately labelled preset first black stone; every subsequent move is an actual `GomokuBot.chooseMove` decision and is applied through the matching `GomokuState` implementation.
4. Audited every new move independently in Python; retained external JSONL shards and checksums only, never player history or an Inbox binary/archive.
5. Performed a 200-opening-block / 400-game colour-swapped Bagua-vs-off control. It does not meet the promotion threshold.

## External artefacts (not committed by design)

Root: `/workspace/veillink-gomoku-training-QkowvH/output/`

- `s1-1000.jsonl` — SHA-256 `2953b457c7992dbeb2e72af55ba99779a8e4dba071b34c5385c70b3b63a4a2d9`
- `s1-1000-audit.json` — SHA-256 `6a78e5ccee01cb7ac2ca463123b828165aa8f420d1683b8e39453dbe362adfc0`
- `s1-1000-bagua-analysis.json` — SHA-256 `cf8f75087a8c7e110a2ce609508cb33dbcd536bae93a6c6400d5710b8b7dcdf1`
- `tournament-bagua-paired.json` — SHA-256 `1025357d756047d3b15fb1cb395947621d319b1fc66f4d71094121ba3b312a65`

Raw game data is intentionally excluded from Git Inbox under the repository artifact policy.
