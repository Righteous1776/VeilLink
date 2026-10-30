# Test plan and evidence

## Completed locally

- `git diff --check`: PASS.
- Patch generated against exact baseline `403b3dc474746d3925ad52fa4169225905bac7fc`.
- `python3 scripts/verify-tactical-v2-assets.py`: PASS.
  - map dimensions: 48×27;
  - cells: 1,296;
  - macro sectors: 18;
  - asset SHA-256: `4bd450353ae993b0c8083b97ab5909c8260cd6984be6f6051db1967613edaaa5`.
- Info.plist parse: PASS; `LSSupportsOpeningDocumentsInPlace=true`.
- Source scan: no board-learning fixed `maximumPositions`, `maximumRecentGames` or `maximumBytes`.
- Source scan: Game Lobby no longer routes 三国兵器 to `LocalAIGameView(... .tactical)`.
- Attached training package audit: PASS; see `TRAINING_AUDIT.md`.

## Added automated tests

- all 2,400 synthetic positions persist (old cap regression);
- game-scoped stores do not leak Gomoku data into Xiangqi;
- two repeated interrupted Xiangqi lines penalize the old AI reply and predict the next human move;
- import/export checksum round trip remains covered;
- provider file is materialized and remains readable after picker handoff;
- wrong extension is rejected after the permissive Apple Files picker.
- a V1 mixed shared learning file migrates into two scoped V2 stores while its source bytes remain unchanged.
- Gomoku and Xiangqi difficulty budgets monotonically increase search capacity; retained training evidence also reinforces every tier's bounded search budget; a repeated Xiangqi opening produces an explainable personal-coach profile.

## Mandatory Apple SDK gates (not available in this Linux workspace)

1. `xcodegen generate`.
2. iOS 15 build for simulator and generic device.
3. Complete XCTest suite, including new learning/import tests.
4. iPhone 7 / iOS 15.8.x:
   - select local, iCloud and third-party-provider files, including a 200 MiB backup; cancel during staging and confirm UI responsiveness plus temporary-file cleanup;
   - import `.vltrain.json`, backup ZIP, HTML, image and arbitrary integrity-test file;
   - cancel picker and cancel backup-password sheet without stale staged data;
   - repeat a fixed Xiangqi line at least three times and confirm “阵法预判” plus changed legal AI response;
   - switch every tier on iPhone 7 and a newer device, verify that all tiers retain trained responses, and ensure the Master budget does not cause thermal/background termination;
   - verify Gomoku/Xiangqi summaries remain independent across relaunch;
   - enter A10-only and confirm Settings and Owner Console continuously show A10 sample/health/budget;
   - open 三国兵器 in portrait and landscape, pan/zoom the 48×27 map, issue ten turns, background/foreground, restart.
5. P0 signing/consent/touch regression from the V27 release gate.

## Release boundary

This submission must not produce an IPA. A later release requires a new live lane grant after all gates above pass.
