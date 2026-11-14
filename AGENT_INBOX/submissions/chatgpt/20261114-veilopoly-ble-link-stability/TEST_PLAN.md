# Verification Plan — Veilopoly and BLE

## Automated staged regression tests
- `VeilopolyNetTests/RoomLinkPolicyTests.swift`: idle times 0, 15, >15, 120, 3600 and nonfinite; a healthy secure session is never treated as disconnected; actual missing secure session pauses game.
- `VeilopolyInvitationBridgeTests.swift`: create guest room on fake authenticated channel, mark synchronized, advance clock 30s, assert no false offline or unwanted security recovery; remove secure session and assert game pauses.
- `BLELinkReliabilityPolicyTests.swift`: bounded 2s stall probes, none without ready channel, pending packets, or stall threshold.
- Existing suite: `BLETransportSafetyTests`, `BLEGattHandshakeWatchdogTests`, `BLELinkSnapshotTests`, `BLEConnectionIntentStoreTests`, `VeilopolyNetTests` all need macOS Xcode/SwiftPM execution.

## Governor verification gates
1. `git apply --check --whitespace=error PATCH.diff` from exact `af3d823546c288169d19cb3033a6111977d28bd7`; compare resulting files byte-for-byte with staged `FILES/`.
2. XcodeGen/iOS simulator Debug build, iOS minimum target compatibility and Swift 6 strict concurrency warnings.
3. Two physical devices offline: continuous chat and Veilopoly for 30+ minutes under weak RSSI, walls, Bluetooth audio coexistence, foreground and allowed background transitions.
4. Induce `canSendWriteWithoutResponse == false` and peripheral `updateValue == false` while streaming: queued bytes must persist, control packets progress after backpressure clears.
5. Force genuine Bluetooth off / explicit disconnect / remote disappearance: no false online status; eventual disconnect/reconnect reported by CoreBluetooth.
6. Verify repeated invitations, room resume, authoritative host snapshots, no duplicate game commits, no security-session churn, no packet loss, bounded memory and CPU/radio cost.

## Not claimed
No iOS SDK build, XCTest on Apple hardware, radio throughput benchmark, two-phone acceptance, integration into main, or IPA build has been executed by this Inbox submission.
