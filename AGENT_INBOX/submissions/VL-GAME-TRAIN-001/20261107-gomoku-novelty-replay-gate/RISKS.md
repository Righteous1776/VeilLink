# Risk and Overlap
- An opening grid alone increases potential variation but is not an Elo/strength proof. Deep tactical scoring still owned by `GomokuBot.swift` and separate governance.
- Exact sequence dedup stops future identical training replays without deleting owner historical records. It can lower reported novel-training count and should be communicated explicitly.
- Full legal replay costs a linear pass per finished game; bounded 225 moves and done off-main/UI. Verify on iPhone7 memory/cpu.
- `Set<[String]>` scales with historical `recentGames`; the current 5,141-game archive is manageable, but stress test 100k history before high-scale deployment.
- Existing agent PRs #111 / #128 / #159 / #161 / bundled native seed/tests may have semantic overlap; Governor controls reconciliation. No unilateral engine rewrite.
- Export importer is REPLACING not merging; do not load shadow or original alternative over user archive without backup.
- Actual user supplied gameplay logs MUST NOT be uploaded publicly by this lane. No binary data, model weights, IPA or signing information submitted.
