# R14 Integration Gate / Test Plan

### Already executed in this turn
1. Current main `eb487a19` confirmed.
2. R13 overlay 6 kernel hunks: 5 unique exact matches against selected #213 full kernel; overlapping Limits hunk explicitly merged retaining both default-FALSE switches.
3. #209 controller vs #208 UI/history: 14/15 hunks exact; remaining AI decision hunk manually reconciled into one typed native callback.
4. Combined product patch `PATCH.diff`: **21/21 paths** (4 changed + 17 add), **47/47 hunks** (30 modified +17 new) applied and validated via exact old-source replay in memory; 4 modified results byte-identical to staged merged source, 17 new-file add blocks generated from staged source.
5. Pure source probes: frozen model reference intact, #213 leaf and #214 index present, defaults OFF, no JSCore invocation in R14 controller, selected native callbacks for 1/2/3-ply real moves, session-restricted redacted depth/nodes.

### Previously executed by OTHER agents on their independent versions — not R14 merged test results
- #209: 500 model-v-baseline + 420 difficulty-calibration completed games, 9024 score/feature parity, 82 tactical, native product bridge integration.
- #213: 1607 independent classifier checks, 192 arena-derived tactical fixtures.
- #214: 14691 incremental-index assertions, microbench of a specific fork query 14.65–17.98x, **NOT full engine speed**.
- #208: 33 real-trace + prior 505 local checks, without the trained-kernel convergence.

### Mandatory NOT_RUN gates before product merge
On an authorized clean integration branch, copy `PATCH.diff` from this Inbox and run:
```bash
git checkout -b integration/eclipse-r14 origin/main
git apply --check PATCH.diff
git apply PATCH.diff
xcodegen generate --spec project.yml
xcodebuild -project VeilLink.xcodeproj -scheme VeilLink -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO build test
```
Choose a simulator actually installed on CI and ensure app tests are authorized. Confirm `project.yml` auto-includes VeilLink/Agent/Games and VeilLink/UI new Swift and VeilLinkTests files. Verify iOS 15.0 target and Swift 5.9 strict-concurrency compatibility.

Run:
- R14 XCTests: frozen R12/R13 flags off; observer-on vs observer-off same move/score/complete depth on fixed safe boards; every observed path is a legal actual 1–3-ply board continuation.
- Existing R4/R6/R8 safety and 212 historic fork fixture checks, full 920-game published journal replay, old game restore/migration and per-game archive.
- Fresh matched-opening color-swap native-v-native gameplay. Separately A/B test R12-only ON, R13-only ON, both ON under identical time/node budgets; no use of 920 previously examined games as a new independent holdout.
- Real-device frame budget and search slowdown with visualization ON vs OFF, 15x15 board gestures, dark/light/all five themes, VoiceOver and Reduce Motion.
- Cancellation/restart/teaching/old external preference restored, no stale candidate coordinates, no false status, no archive loss.
- Root tactical gate, threat semantics, code license/third-party removal review.

**Any Xcode compile/test failure blocks release.** No workflow dispatch, merge, version change or signed IPA authorized within this Inbox drop.
