# Reproduced Build64 bug

`VeilStorageMaintenance` exposes a “过期临时文件” category, but its allow-list omits two files that Build64 itself creates in `temporaryDirectory`:

- `VeilLink-GomokuLearning-*.vltrain.json` and `VeilLink-XiangqiLearning-*.vltrain.json`
- `VeilLink-PreConsent-*.json`

Consequently these exports are never counted or removed by the user's cache/storage cleanup screen, even after the documented 24-hour stale threshold. Repeated training export and pre-consent diagnostics can therefore make the app's temporary footprint grow invisibly.

# Proposed repair

1. Extend the existing stale-artifact predicate with exact prefix and suffix pairs for both board-learning formats and the pre-consent JSON export.
2. Preserve the 24-hour age threshold, direct-child root boundary and symlink rejection.
3. Require `.vltrain.json` for board learning and `.json` for pre-consent, so a lookalike text file is retained.
4. Add a regression that verifies scan count, deletion count and lookalike preservation.

The player's persistent learning database and Documents backup exports are not touched.
