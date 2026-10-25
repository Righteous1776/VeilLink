# Risks / overlaps

1. Old-device P0: first-consent and Keychain continuity, touch gesture overlays, and iOS15 UI input remain unresolved; PRs #64/#65/#66 must be arbitrated first.
2. R2/R3 metadata PRs #73 and #75 reference prototype sources distributed externally. R4 maintains those R3 engines; do NOT import both R3 and R4 under identical Swift type names.
3. GitHub source staging is **limited** to admission gate + tests. Remaining full source patch, 200-entry machine catalog and episode content are only in the R4 local ZIP. Do NOT treat a merge of this PR as completed product integration.
4. Chapter briefs and art/sound directions are **content production plans**, not playable scenes/media. Third-party licensing is not assumed.
5. R4 E091 adds visited state with a backward-compatible decoder for R3 prototype JSON; no production DB migration or rollback has been executed or authorized.
6. Planned budgets (30 fps, memory), 200 inter-world candidate links, audio latency and battery claims remain unmeasured or disabled.
