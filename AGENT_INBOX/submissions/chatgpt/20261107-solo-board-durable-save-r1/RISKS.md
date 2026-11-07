# Risks
Source integration overlaps PR #128 side-choice controller; must merge with persistence of selected human role.
Synchronous replay validation + atomic save after each move may cost CPU/I/O in long Xiangqi games; measure iPhone7 latency.
Corrupt read freezes overwrite to protect original file; intentional restart allows clear.
Finished games restored for review, but a crash in the final-move-save vs learning-archive window can miss final training record (not duplicate).
No persistence of developer formation editor mid-lesson; this patch covers ordinary singleplayer Gomoku/Xiangqi only.
All code in Inbox PATCH.diff, not product main. Xcode/XCTest and physical recovery NOT_RUN.