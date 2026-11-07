# VLP-CODEX-W1-006 — movable, suspendable panel workspace

- Branch: `dev/veilopoly`; exact source baseline `fb245c3d41b42fe1e8b031cd342f7316aefb4fc7`.
- Main read back unchanged: `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
- Authority: current Owner asks to continue existing panel UI, not replace it.
  #168 lane + Owner's scoped P5 override remain in force; this wave needs ONLY
  `VEILOPOLY_DEV/**`. No host, Engine/AI/Net/Persistence, economic rules, saves,
  shared identity/DB/Wire/transport, art blobs, project, version or workflows edited.
- Existing `4c76015..fb245c3` source was fast-forwarded before edits, not overwritten.
  Independent V5 and V5 risk-review branches remain untouched/unmerged. No other
  panel writer was found in current #6/#168; no force-push or conflict resolution.

## Implemented

1. Keep the complete board's existing fixed aspect-fit measurement and camera.
   A new UI-only normalized anchor/layout policy constrains panel and chip to
   the safe GeometryReader viewport, below a reserved 54pt news/More/Exit strip.
   Dragging clamps to edges; no momentum throw. Resizing recomputes positions.
   Invalid/tiny/nonfinite geometry cannot create a negative/NaN frame.
2. Only the panel TITLE handle moves the window. Content scroll, chart gestures,
   native buttons and the existing numeric keypad keep separate hit areas.
   A 44pt toolbar exposes labelled **挂起 / 资料 / 停靠** controls. Suspension
   stays at the LEFT of the panel, retaining the earlier Owner Exit separation.
   Non-drag left/right docking and reset are available from an accessible menu;
   More also resets both positions if the user loses the preferred placement.
3. Suspension retains the mounted drawer (opacity + touch/accessibility removal,
   not conditional deletion), preserving same-phase local stock-ticket state,
   scroll/disclosure and current section. The 280×72pt chip restores it, shows
   actor/cash/phase and pending-decision text, and has its own separate drag grip
   and VoiceOver docking actions. Locations are presentation/session state only,
   NOT persisted game data. Restart resets them. No cross-launch, orientation-
   subtree replacement, actor change or section-change draft retention promised.
4. A new purchase/auction/trade/debt/settlement opens once, after pending visuals
   finish. Re-observing the SAME decision cannot reopen a deliberately suspended
   window. A new actor, phase, purchase/auction subject or session can notify
   again. Existing render ACK/card modal and phase/actor/section scroll reset stay.
   Suspension does NOT pause AI/market/network, end a turn, cancel a trade,
   automatically buy/fold, clear a save or manufacture a game action.
5. Network detail and account data are inside the scroll area, not competing
   pinned headers. Secondary tile/four-player detail is a disclosure. Tapping a
   board cell opens it. Management tabs and the real end-turn button stay outside
   the scroll area. Reuse signed Astra dark-teal instrument art, gold trim and
   existing day/night theme; no new decorative controls, image/font dependency.
   Reduce Motion removes explicit open/suspend fades.

## Occlusion contract (not an impossible blanket guarantee)

- Panel/chip cannot reach the reserved top strip; hidden drawer cannot intercept
  board taps or VoiceOver. Cards remain intentional modal overlays above all UI.
- Default 844×390 / 852×393 / 724×342 geometry fits the panel beside the board.
  Mathematical tests also cover 568×320 and 1180×820. Actual safe areas differ.
- A maximized iPad board + a usable 395pt panel cannot always fit side-by-side.
  The panel may intentionally overlap board tiles there, or wherever the user
  drags it. Move or suspend it to reveal those tiles. We do NOT shrink/crop/zoom
  the board on panel changes or falsely claim zero board overlap at all sizes.
- Source-metric tests reserve >=80pt for the title and >=80pt for the scroll area
  in compact reference geometries. These are NOT measured Dynamic Type hitboxes.

## Validation

Commands use Linux Swift 6.2.1; **none constitutes an Apple UI acceptance**.

- Before edits: `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2
  --filter VeilopolyUITests` → 99 cases / 0 failures → PASS.
- New `PanelWorkspaceTests` → 11 cases covering placement, clamps, malformed
  geometry, resize, suspension/decision identity/reset, top strip, compact
  geometry and board independence → PASS.
- Final UI-target portable tests → 110 cases / 0 failures → PASS.
- First full run → 327 cases / 1 failure / 64.233s → FAIL. The failure is the
  existing `MalformedTurnReferenceTests.testMalformedTradePartiesAndTiles:21`.
  Its existing fixture includes tile index4 (a nonpurchasable tax cell) alongside
  out-of-range party indices. Existing guard checks bounds only; later handler
  returns a different failure than its expected `invalidState`. No acceptance
  or crash from a UI click is established by that assertion. Engine/test blobs
  are unchanged this wave. Isolated same-case repeat also FAIL.
- Final full run → **329 cases / 1 failure / 84.480s** → FAIL, same existing
  trade assertion only. This supersedes the first full run above (two more
  panel-geometry cases added). No whole-package PASS claim.
- `git archive fb245c3` extracted to an isolated `/tmp/veilopoly-panel-baseline.*`
  directory, then exact clean baseline `swift test --jobs 2 --filter
  MalformedTurnReferenceTests` → **4 cases / 1 failure / 0.046s** → FAIL, same
  source assertion at line21. This reproduction contains NONE of this UI patch.
  Neither Engine implementation nor baseline test was modified or suppressed.
- iOS15 ARM64 frontend `swiftc -frontend -parse` → syntax only → PASS.
- `git diff --check` and scoped/protected-path review → PASS.
- Apple SDK SwiftUI/host typecheck, XCTest, Simulator, real iPhone/iPad rendering,
  touch/gesture conflicts, VoiceOver/focus, Dynamic Type, performance → NOT_RUN.
  `xcodebuild` is unavailable in this executor. No PR/dispatch to produce an IPA.
- Historical strict Codable warnings gate remains unresolved; strict build was
  NOT_RUN this wave and is not represented as green.

## Manual Apple gate / next task

`VLP-CODEX-W1-007`: compile the exact head with Apple SDK (iOS15 compatible), then
render 844×390, 852×393, actual iPhone safe areas, 1180×820 and resized iPad:

- Drag title and chip to every corner; assert capsule/news never blocked and
  release does not jump/double-apply translation. Check no invisible touch layer.
- In bank/stock/trade set draft numbers, chart/portfolio disclosure and scroll;
  suspend/restore during the SAME phase, without placing an order or losing state.
- Suspend purchase/auction/debt; ticks/ACK do not reopen it; new decision does.
  Card confirmation stays above everything and ACK completes exactly once.
- Content scroll/long-press chart/keypad must not drag the window. Check dock,
  reset, read-only asset sheet return, pending-host and network failure states.
- Day/night, Reduce Motion, VoiceOver docking/focus, accessibility text sizes;
  no default nonresponsive controls. Measure hidden-panel update/resource cost.

Separate baseline Engine failure needs a scoped W2 follow-up; do NOT weaken its
assertion or silently change financial/trade rules as part of this UI patch.
Main merge/release/IPA gates remain closed. State: UI SOURCE IMPLEMENTED,
PORTABLE UI VALIDATED; WHOLE PACKAGE FAIL / APPLE ACCEPTANCE OPEN.

## Governance/skill evidence

Governance skill caused scope/continuation/overlap checks and explicit separation
of SOURCE, portable and Apple results. Actual repo's Inbox is V1.1: supplemental
`governance/CONSTITUTION_SEAL.json`, `MANDATORY_READ_SET.json`,
`AGENT_INBOX/07_LEARNING_GATE.md`, study/session/exchange tooling are absent.
Supplemental dual-machine learning gate therefore PARTIAL/UNAVAILABLE, NOT PASS;
no replacement governance installed or authority record edited. Current explicit
Owner + #168 live scope, unchanged main governance and real Git remain authority.
