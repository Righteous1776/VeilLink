# ECLIPSE R17.2 — Mechanical telemetry / event-bound motion

**Style:** Same user-approved VeilLink orange/black/grey/silver with warm-brown board; no green override, no new image assets, no global theme changes.

## Instruments and their provenance
1. **Search clock dial** (on the telemetry deck) uses `LocalAIGameController.eclipseSearchStartedAt` and elapsed wall time, refreshed only while visible in active scene. With an explicitly custom time cap, the orange ring represents **elapsed share of user-set time budget**, never an estimate of algorithm completion; in automatic/untimed it is a rotating indicator without progress semantics. No synthetic nodes.
2. **Compute console** keeps its preexisting optional *decorative* terminal stream and adds clearly labeled **REAL CLOCK T+**; the adjacent cycling LEDs are a clock-effect only, never engine output. Real-time node/depth telemetry is still shown only when genuinely supplied.
3. **Last decision metric grid** displays real `lastDecisionNodes`, `lastDecisionMilliseconds`, calculated approximate node throughput and saved native training-game count, blank when no measurements.
4. **Node use gauge** compares the actual measured previous search nodes against a snapshot of the exact search-specific node ceiling at decision start. This prevents retroactive comparison against newly edited slider values. Automatic mode and missing metadata display **NO COMPARABLE BUDGET**, not invented precision.
5. **Tactical signal** reflects exact rule-based one-move-win counts for either side; text announces offense/defense/neutral status, not AI confidence or proposed coordinates.
6. **Board impact pulse** happens only when `GomokuState.lastMove` changes on the offline human-vs-ECLIPSE board. Orange lock ring expands for 0.65 s, no continuous board animation, no active touch surface, not applied to multiplayer or Xiangqi.
7. **ECLIPSE avatar** has low-density mechanical tick rim and a small orange scanning arc only while the native engine is truly computing. Inactive card remains still.

## Motion safeguards
- Added no `DragGesture`, `simultaneousGesture`, overlay `Button`, or scroll gesture interceptor. The original `VeilBoardTapSurface` remains authoritative. Every new overlay has `.allowsHitTesting(false)`.
- `accessibilityReduceMotion`: numeric readouts remain readable; avatar rotation and board pulse stop; dashboard numeric transitions are disabled, dial clock still updates slowly.
- Scene inactive: dial/console cadence throttles, avatar rotation stops. Low Power mode: animation cadence is reduced. The console's compact layout reserves a stable 66pt minimum to avoid jumps when AI starts.
- No persistent frame timer, no retained PV/candidates, no false model confidence, no audio, no image assets.

## Authority and integration
- INBOX_ONLY candidate. **Not merged** to main or a release. The R16 local engine and PR #220 source remain integration prerequisites, as specified in R17.1 manifest.
- `R17_ADVISORY.patch` is against the documented R16/PR#220 **hybrid** in earlier inbox handoff; do not apply to main directly.
- `R17_2_FROM_R17_1.patch` is a review-only delta against the already handed-off full R17.1 candidate.

## Real validation performed
- `swiftc -frontend -parse` all 10 Swift candidates, passed (syntax only; not an Xcode/SwiftUI typecheck)
- Existing 7 rule-based one-move-win tests, passed on native Swift 6
- Static motion/gesture/palette assertions, passed
- `git apply --check` from hybrid reference and **byte-identical** apply replay for every affected Swift file, passed
- Native iPhone/iPad rendering, performance, thermal and Xcode integration tests are outstanding
