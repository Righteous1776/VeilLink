# Tests and safety gates
- [x] Existing-file source hunks validated against exact main ccafebab147e069fbabfff579dbf323b0d54f191; no third-party code or assets copied.
- [ ] xcodebuild and XCTest on iOS15 deployment and current iOS26 target, not run.
- [ ] Owner OFF default / authorized visualEffects toggle only / persist across relaunch; no privilege bypass.
- [ ] All 9 computer-opponent interfaces show motion when ON and no view/timeline when OFF.
- [ ] Touch all game board cells, slider/gesture, navigation buttons: mascot must NEVER intercept touches or cover board.
- [ ] Reduce Motion + inactive app pause, low power 15fps, 30fps nominal; long-run iPhone7 thermal/battery/memory test.
- [ ] Thinking/win/loss/draw status matches engine; offline, no network and no copyrighted assets.
- [ ] Rebase/merge reconciliation with #159, #128, #141, #129; no save regression.
