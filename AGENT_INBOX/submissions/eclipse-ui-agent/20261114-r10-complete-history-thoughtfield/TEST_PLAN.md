# R10 Verification

## Local completed

| Test scope | Result |
|---|---|
| Swift 6.2.1 optimized, warnings-as-errors — archive + decorative pattern | 39 PASS |
| Swift 6.2.1 — R9 fair-play and committed-only replay | 18 PASS |
| Swift 6.2.1 — R9 session gate / true vs recorded telemetry / tier label | 35 PASS |
| SwiftUI files syntax (`swiftc -frontend -parse -swift-version 5`) | PASS (parse only) |
| 145 distinct archived matches, pages 30/100/15 | PASS |
| Corrupt JSON preserved, no prior match overwrite, idempotent finalized record | PASS |
| Browser Chromium 320x568, 390x844, 768x1024: click start/stop, history, replay | PASS; no runtime exception/overflow |
| Full proposed patch `git apply --check` against synthetic exact-main snippets | PASS (does not verify full checkout) |

## Integration blocking gates

- Confirm full base SHA and rebase once V9 or R5 integration changes the controller, then run `git apply --check` against a real full checkout.
- Xcode iOS compile, SwiftUI actor isolation, XCTest and physical device interactive gesture tests.
- Simulate archive write failure, low disk, file-protection lock, app kill between final move / final status, crash recovery, restart, color seat swap, and developer teaching board separation.
- Under 1000+ or 10,000+ stored matches benchmark archive paging, disk space and thermal/animation drain.
- Validate no game hints by comparing geometric visual patterns for two different boards with identical tick values: the overlay must not have access to actual state.
- Distinguish generic UI built-in clock from real depth/nodes; no fictitious search telemetry.
- Ensure one-store backups and training exchange unchanged, no old moves erased by clear-learning function.

## Nonclaims

- No equal-budget ELO / win rate, no confirmation that V9 was merged, no iOS runtime verification, no IPA, no source change to `main`.

## Continuation additions
- Three new native checks: oversized JSON rejected before decode, oversized evidence preserved, clock rollback maintains a valid record.
- Search-start visual gating is checked in the proposed GameLobbyView patch; NOT Apple iOS runtime-tested.

## R11 additions
- Build pure Foundation display generator with `swiftc -swift-version 6 -warnings-as-errors -O FILES/VeilEclipseConsoleStream.swift TESTS/R11ConsoleTests.swift -o /tmp/eclipsescreen && /tmp/eclipsescreen` — 413 passing checks locally.
- Previous R10/Policy/Gate tests remained 39 + 18 + 35 = 92 passes; aggregate **505** local assertions.
- `swiftc -frontend -parse -swift-version 5 FILES/VeilEclipseIdentityAndTrace.swift FILES/VeilEclipseComputeConsole.swift` parsed, but no Apple SDK typecheck.
- Browser prototype inspected at 320x640, 390x844, 768x1024 with active/inactive terminal, visible moving text, and opened TRACE (no viewport overflow/error).
- Governor must validate the **combined** `PATCH.diff` against a complete current main checkout; staged patches are advisory and local source-derived/synthetic checks do not constitute full-repo green.
- Xcode/iPhone/iPad/XCTest/thermal/VoiceOver checks NOT EXECUTED.

## R12 new regression results / gates
- Standalone Foundation + exact 15x15 turn/legality stub: `swiftc -swift-version 6 -warnings-as-errors -O GomokuStub.swift VeilEclipseSearchTraceStore.swift R12SearchTraceTests.swift` => 27/27 PASS.
- Re-ran four R10/R11 pure-Swift suites: 39 archive + 18 policy + 35 session + 413 console = 505/505; total 532 checks.
- Renderer SwiftUI parse-only under Swift 5 frontend => PASS; not actual Apple typecheck.
- Rebuilt unified PATCH.diff from exact current-main text, checked 35 hunks on 12 paths: preimage and source-text match. This is an in-memory exact-main preflight, not a full Apple CI/Xcode run.
- REQUIRED: iOS build/XCTest, 3ply native signal from actual iPhone/iPad with Swift actor isolation, cancellation/new-match stress, high-tier search temperature and performance, VoiceOver/Reduce Motion.
- Integration Governor must reconcile GomokuBot signature with PR #199 forced-search and #193/#196/#207/#209/#210 competing search proposals.
