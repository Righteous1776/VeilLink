# Test plan

- Verify two staged JSON files exactly match source checksums and row-major action conventions; re-encode payload with Swift JSONEncoder sortedKeys and verify FNV64.
- Apply PATCH.diff on exact e093e7fb7ab0eb9821a014b753ab2bdc27613ec8; XcodeGen generate, test bundle includes both named .json resources with Bundle.main.url; verify test target discovery.
- Run VeilBaguaFormationTests: knight detection, bounds, insufficient sample caution.
- Run ReviewedBoardSeedMergeTests: one import adds evidence without deleting unrelated records; second same import leaves counts unchanged; restart preserves both.
- Add manual test: corrupt FNV, wrong game (Xiangqi on Gomoku) and invalid move actions must reject without altering local training file.
- UI developer gate: without Owner/app-lock authorization, built-in seed cannot run; authorized button merges without Files picker and updates coach profile.
- Full simulator XCTest, Release iphoneos build and physical iOS15/iOS26 smoke. Check local data preservation on upgrades and existing saved AI levels.
- Compare win/block tactical choices before/after for forced-four positions; bagua style must not override forced tactics.
