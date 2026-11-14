# Blackbox final P1 test gates
- [x] Main SHA `ccafebab147e069fbabfff579dbf323b0d54f191`, GitHub governor docs/Issue#6 refreshed.
- [x] 3 changed-line hunks uniquely applied to identical source snapshot; 2 new source/test files defined.
- [x] Pure numeric policy fixtures: 8/8 in JavaScript; Apple Swift compile NOT_RUN.
- [x] Replay model of 459 brightness snapshots at 2s/0.02 criteria: estimated 7 accepted (98.5% fewer records), not a device performance benchmark.
- [ ] macOS xcodegen, iOS15.8.3 compatible swift build, targeted XCTest and full suite.
- [ ] iPhone 7 automatic brightness sweeping, idle static brightness and 30-minute mixed chat/game stress: compare diagnostic event counts/CPU/memory/thermal/main thread p95.
- [ ] Confirm periodic-30s, startup, thermal, battery and forced incident snapshots retained; no lost forensic coverage.
- [ ] Governor review and integration **after** #137 ordering; new file scope independent, no silent merging of prior agent PRs.
