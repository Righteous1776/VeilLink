# Test Plan

## Static
- Verify all source snapshots are exact main `403b3dc474746d3925ad52fa4169225905bac7fc`.
- Run `git apply --check PATCH.diff`, then inspect the four files changed, no version/CI/package/signing mutation.
- Governor: apply `FILES/PR100_WEBKIT_FOLLOWUP.diff` ONLY to the selected #100 candidate, verifying HEAD and no duplicate Monogatari proposal.

## Tests
- `VeilLinkTests` existing voice and audio lifecycle; add a targeted delayed-old-player-finish regression test where feasible with dependency-injected AVAudioPlayer.
- `VeilStorageMaintenanceTests` clock injection and TimeInterval tests.
- `RhythmNeonScene` texture capture at cold start and memory pressure.
- `ToolCenterView` SwiftUI compile on Swift5.9 and Swift6 strict checker.
- `WKNavigationDelegate` under iOS15 WKWebView: allowed veilnovel://game subpaths, reject http(s), javascript:, other schemes, file:// escape and unauthorized subframes; attach callback count so fallback is detected.
- Full project build with -warn-concurrency, complete XCTest and XCUITest and unchanged protocol/SQLite.
- iPhone7 iOS15.8.3 and modern iPhone iOS26 physical audio, render, Monogatari link/save/relaunch.

## Negative/regressions
- Late audio completion must never stop new playback.
- WKNavigation action callback must be invoked and always call decisionHandler on both allow/cancel.
- Reject synthetically constructed external and mis-encoded URL variations; monitor fatal loop and save corruption.
- No experimental Swift6 blanket warning suppression.
