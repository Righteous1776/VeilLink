# Validation gates
- [x] 14 original-file patch hunks independently re-applied against immutable main ccafebab147e069fbabfff579dbf323b0d54f191; 2 new files counted.
- [ ] macOS Xcode compile, existing XCTest and new LocalBoardMatchStoreTests: NOT_RUN.
- [ ] Real iOS: terminate after user Gomoku stone before AI response, reopen and resume only once.
- [ ] Xiangqi legal move + captures + repeated positions across 30+ moves, restore exact state.
- [ ] Manual tab exit, app suspension, forced kill, low battery, disk-full, file protection state.
- [ ] Corrupted file byte-for-byte preservation and backup before explicit restart.
- [ ] Preserve independent Xiangqi/Gomoku save slots, learning archive, developer formation recorder.
- [ ] Governor resolve #128, #129 and #141 overlapping source before merge.
