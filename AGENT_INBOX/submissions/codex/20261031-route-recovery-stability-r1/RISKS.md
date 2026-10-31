# Risks — route recovery stability R1

- Apple compilation, XCTest execution and real Network.framework state injection are unavailable in this Linux image.
- Network.framework may emit `.cancelled` after a prior `.failed`; the active-object identity guard and immediate slot clearing ensure only the first terminal event can schedule recovery.
- Recovery still uses the existing finite retry budget. After the budget is exhausted, manual refresh remains required; this patch does not introduce an infinite background loop.
- Relay failure accounting becomes less aggressive than the buggy double count but matches the existing explicit threshold of two consecutive failures.
- PR #97 edits BLE handshake recovery. This proposal edits LAN and Internet relay files only; combined end-to-end route arbitration still needs Governor validation.

Rollback is a clean reversal of the three-file patch; no data or protocol rollback is required.
