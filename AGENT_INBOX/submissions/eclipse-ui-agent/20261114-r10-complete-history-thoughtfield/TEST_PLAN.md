# R10 Verification

## Local completed

| Test scope | Result |
|---|---|
| Swift 6.2.1 optimized, warnings-as-errors — archive + decorative pattern | 36 PASS |
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
