# ECLIPSE R17.2 — Mechanical Intelligence Cockpit / INBOX_ONLY

**Authority:** Owner → Integration Governor VEILLINK-IG-001 → Lane INBOX_ONLY. No direct main edits, merge, release, IPA, manually triggered Actions, or training-weight changes.

**User direction:** Preserve the real iPhone **original VeilLink orange** UI with deep grey cards, warm brown Gomoku board, black code console and white/silver text. Make the cockpit more mechanical and emotionally engaging through **genuine, readable information-bearing animations**, not colorful decoration or fake AI reasoning.

**Baseline:** R17.1 (PR #234 inbox), built upon R16 local engine + PR #220 user interface. Do not apply full patch directly to main. See `COLOR_REGRESSION.md` and `MOTION_SPEC.md`.

## Changed since R17.1
1. `VeilLink/UI/GameLobbyView.swift`: measured live search dial with correct budget semantics; four measured game/engine statistics; snapshot-consistent node budget meter; numeric state transitions; tactical signal labels; active search status; throttle/ReduceMotion behavior.
2. `VeilLink/UI/MiniGameViews.swift`: opt-in offline ECLIPSE-only mechanical orange move ring with a single 0.65s event-bound expansion and no gesture hooks.
3. `VeilLink/UI/VeilEclipseIdentityAndTrace.swift`: quiet 16-tick mechanical bezel and an orange computing-only scan arc.
4. `VeilLink/UI/VeilEclipseComputeConsole.swift`: actual elapsed time in preexisting decorative code screen; bounded clock-cycle LED strip with honest labeling; stable compact layout and low-power cadence.
5. `VeilLink/Agent/Games/LocalAIGameController.swift`: record actual previous decision's node-limit snapshot once per move, preventing current slider changes from falsifying the gauge. No search algorithm altered.

**Unchanged**: five other Swift files (R16 engine/search dependencies and R17.1 ThoughtField). The full 10-file candidate is supplied under `FILES/VeilLink/...`; do not apply source files to main without Governor dependency resolution.

## Payload
- `FILES/`: 10 current Swift candidate sources
- `R17_ADVISORY.patch`: full hybrid-baseline advisory diff
- `R17_2_FROM_R17_1.patch`: incremental R17.1→R17.2 review diff
- `COLOR_REGRESSION.md` and `MOTION_SPEC.md`: approved visuals and animation provenance
- `RISKS.md`, `TEST_PLAN.md`, `SHA256.json` and `TESTS/`: verification/reproduction materials

## Verified
- Swift 6.2.1 syntax parse: **10/10 passed**, full Xcode typecheck **not run**
- Rules tests: **7/7 passed**
- Static animation/privacy/gesture audit: **passed**
- `git apply --check` & exact-byte hybrid replay: **passed**

**Not verified:** actual iPhone screenshot/animation smoothness, native UI typecheck, thermal load, IPA. This is a review candidate only.
