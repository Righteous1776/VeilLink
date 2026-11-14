# ECLIPSE R17 — Tactical Cockpit / UI-overhaul Inbox Candidate

**Authority:** Agent `INBOX_ONLY`, no main/source mutation, no release/IPA, no Actions manually launched.
**Scope:** Gomoku-only visual layer and the existing R16 advanced controls, plus one actual engine decision telemetry field. Other games and user training database unchanged.

## Source baselines / critical integration dependency
- `GameLobbyView.swift`, `LocalAIGameController.swift`: R16 local candidate from `VeilLink_ECLIPSE_R16_Advanced_Thinking_Control_20261114.zip`, itself based on the Nov 14 R14 integration branch. The R16 search options and their four native core files are carried in `FILES/`.
- `MiniGameViews.swift`, `VeilEclipseIdentityAndTrace.swift`, `VeilEclipseComputeConsole.swift`, `VeilEclipseBoardThoughtField.swift`: PR #220 integration candidate `integration/v29-1-gomoku-eclipse-seven-tier-model-free-20261114` before R17 changes.
- **Do NOT apply directly to main** until the Integration Governor resolves PR #220, confirms the R16 search baseline, and verifies Xcode project file membership. The patch deliberately does not touch `main`, release numbers, signing or `.pbxproj`.

## What changed
1. **ECLIPSE-only visual identity:** graphite/black surfaces, silver/white text, semantic green/amber/red. Retains the existing original avatar and `VeilEclipseComputeConsole` animation, rather than depicting pretend engine thoughts.
2. **Distinct match cockpit:** seat picker, compact original model identity, dark 15×15 board, selected last-move green ring, clear status, quick difficulty and deep-search controls; rest of the lobby/game modes retain their style.
3. **Real telemetry:** last *completed* decision's actual `GomokuBotMove.nodes` and elapsed time, plus native completed training-games count and current mode string. These are not "live confidence" or invented evaluation scores.
4. **Exact tactical readout:** two counts of legal empty intersections which immediately complete five for each side; no coordinates revealed, no suggestion/probability claims. Pure read-only geometry.
5. **Real advanced settings pane:** two sections Compute and Training. R16 wired `EclipseAdvancedOptions`: automatic/custom (5–300 seconds)/untimed, nodes 50K–2M, depth 3–12, R12 + R13 toggles; persist from next move. Training panel retains original native self-play and export controls.
6. **Touch integrity:** original `VeilBoardTapSurface` and scroll gesture behavior unmodified. `eclipseConsoleStyle` is opt-in, so BLE multiplayer and other boards remain unchanged.
7. **Minor correctness fix:** board footer takes `controller.humanPlayer` instead of permanently assuming black.

## Test results
- Linux Swift 6 `swiftc -frontend -parse` on all submitted Swift files: PASS.
- Linux Swift 6 native rule-based tactical readout scenarios: PASS (empty, both colors, 2-ended four, rotation, no false positive); source extracted from shipped `GameLobbyView.swift`.
- Static contract checks: PASS (controllers bound, palette, no fake metrics, no board-touch rewrite).
- Patch `git apply --check` and byte-for-byte reapplication: PASS.
- **NOT claimed:** complete iOS/Xcode/SwiftUI module typecheck, iPhone 13/iPad layout screenshot, CPU/thermal metrics, upstream PR #220 CI, IPA, large-scale game strength gains.

## Governor integration checks (mandatory)
- Merge/rebase against approved V29.1/R14 base; first integrate R16 source if not already present. `R17_ADVISORY.patch` is relative to a documented hybrid source baseline, not `main`.
- Xcode 26 compile of all UI and R16 search classes; ensure `VeilEclipseChrome` has a single declaration.
- On 375pt/390pt/768pt widths verify no truncated controls; verify both color schemes and VoiceOver.
- Open/close sheet; change time/limits/R12/R13 and test persistence; cancel an untimed search; verify no late move after restart.
- Verify both Gomoku human-seat choices, archive restoration, no moves added by decor, and untouched BLE Gomoku board.
- Monitor FPS/power/thermals when visualizer enabled; conditionally reduce animation if needed.

**Risk notes:** Native computation is still bounded by depth/nodes even in untimed mode. On-device iOS background scheduling cannot be guaranteed. `VeilEclipseComputeConsole` has labeled decorative stream; only numbered statistics described as measured reflect actual engine results.
