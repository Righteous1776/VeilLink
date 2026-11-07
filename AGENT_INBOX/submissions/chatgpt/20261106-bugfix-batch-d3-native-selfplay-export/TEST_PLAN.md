# D3 test plan

## Validation performed in this proposal
- [x] Exact source anchors fetched from main@ccafebab147e069fbabfff579dbf323b0d54f191.
- [x] All 5 mandatory Inbox files are text; only Inbox is written.
- [x] Deterministic patch generation: all 4 source files have unique matching anchors, nonoverlapping hunks.
- [x] Source-read reasoning: `recentGames` has ordered `actions`, `result`, `finishedAt`; `exportPackage` wraps database plus checksum.

## Xcode / XCTest / device: NOT_RUN
1. Apply PATCH.diff to dedicated integration branch, run `git apply --check` and `git apply`.
2. Xcode compile, native self-play + AdaptiveBoardLearning XCTest suites.
3. Existing `NativeGomokuSelfPlayTests` new assertions check exact moves, win result, timestamp, completed count, filename.
4. Real iPhone/iPad: seed import ongoing -> button disabled; no saved games -> button disabled; ≥1 saved game -> Files/AirDrop ShareSheet opens with JSON; compare exported `recentGames[].actions` to actual replay, try 10/100/1000 games.
5. Existing “导出训练包” remains player-only; user export files do not overwrite each other.
6. Reopen app and export again; ensure downloaded file persists after temporary URL cleanup.
7. Stress many stored games: monitor main-thread stall and memory on 2,000+ games; if freeze, Governor should defer or implement detached snapshot serialization before release.

Truthfulness: no Apple SDK, simulator, physical-device or end-to-end ShareSheet run performed in this turn.
