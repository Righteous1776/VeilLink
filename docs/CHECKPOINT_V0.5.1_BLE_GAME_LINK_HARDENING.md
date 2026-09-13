# VeilLink V0.5.1 — BLE Game Link Hardening

## Scope

V0.5.1 is a transport-hardening checkpoint for chat and encrypted games. It does not change Protocol 4, VLGM1 v1, SQLite Schema V8, cryptographic domains, attachment chunk size, or the 三国兵棋 ruleset.

## Reliability changes

- Control traffic (Hello, ACK, attachment checkpoints, text, and mini-game events) can use a bounded overflow lane when the normal per-peer queue is already full of bulk media fragments. Bulk media keeps the historical full queue cap, so legacy 48 KiB attachment chunks are not made unsendable on small ATT values.
- A stalled queue containing control traffic triggers recovery sooner than a bulk-only queue.
- Initial reconnect attempts use a faster capped backoff: 0.5s, 1s, 2s, 4s, 8s, 15s, 24s, then 30s maximum.
- User connection intent is persisted by BLE peripheral UUID. On ordinary process relaunch, VeilLink asks CoreBluetooth to retrieve known peripherals and resumes reconnect attempts. Explicit pause/disconnect clears that intent.
- Foreground activation re-arms scanning/advertising, retrieves desired peripherals, performs an immediate stall check, and refreshes RSSI. Aggressive queue-stall recovery is suppressed while the app is background-scheduled so iOS throttling is not mistaken for radio failure.
- Game Hub shows live BLE transport readiness instead of presenting encrypted-game recovery as an invisible background detail.

## Local validation

The LocalLab adds a CoreBluetooth/Combine API-shape stub so `BLETransport.swift` is typechecked on Linux in addition to syntax parsing. Unit coverage includes control overflow admission, bulk-cap preservation, faster control-stall recovery, and reconnect backoff. Real CoreBluetooth behavior, Simulator XCTest, iphoneos Release build and dual-device reconnection remain macOS/physical-device gates for Work.
