# Test plan — game multiplayer reliability R1

## Executed here

- `git diff --check` on the isolated candidate: PASS.
- Exact baseline and four-file patch scope checked: PASS.
- Static call-path review: outbound validation runs before encoding/queue persistence; receive decoding uses the same validator.
- Regression construction confirms terminal statuses (`finished`, `declined`, `cancelled`) cannot suppress a live rematch.

The current execution image has no `swift`, `xcodegen` or `xcodebuild`; no Apple compilation or XCTest result is claimed.

## Required Governor gates

1. Replay `PATCH.diff` against `403b3dc474746d3925ad52fa4169225905bac7fc` with strict context.
2. Run XcodeGen and compile the iOS 15 target.
3. Run complete XCTest, including:
   - `testOutboundValidationRejectsMalformedCommandBeforeQueueing`
   - `testTerminalHistoryDoesNotHideQuickRematch`
   - all existing `MiniGameTests` and transport tests.
4. Two-device game matrix (iPhone 7 plus a newer iPhone): invite/accept, rapid rematch after win/decline/cancel, duplicate delivery, disconnect/reconnect, resign and app relaunch recovery.
5. LAN/relay path: verify secure-session-ready status without a BLE snapshot and confirm ACK/delivery badge changes.
6. BLE path: verify status still shows BLE health detail and does not regress PR #97's separately governed handshake work.

Any state divergence, vanished invite, invalid command queue insertion or P0 touch failure blocks integration.
