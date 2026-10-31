# Test plan

1. Gomoku defaults to black/first and preserves the Build64 observable labels.
2. Select white/second: board restarts, AI host makes exactly one legal opening, then player guest can act.
3. Xiangqi defaults to red/first; select black/second and verify AI red makes one legal move.
4. Switch sides while AI is thinking: old task is cancelled, session ID changes, and no ghost move enters the restarted board.
5. Run native and external Gomoku engines on both physical colours; rule-gate actor equals the selected computer actor.
6. Save, cold-load and export games from both colours; verify the local-human/computer reward roles remain stable and no old archive is rewritten.
7. Forced-win, forced-block, Veil Bagua dynamic containment and all four difficulty tests under both colours.
8. XcodeGen, simulator build, full XCTest/UI smoke, unsigned iPhoneOS compile. Physical iPhone 7 touch test remains required before release.
