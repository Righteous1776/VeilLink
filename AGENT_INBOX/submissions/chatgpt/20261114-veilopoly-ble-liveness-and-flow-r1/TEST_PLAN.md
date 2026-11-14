# Validation plan

## Source and automated tests
- Exact anchor verification against `main` af3d823546c288169d19cb3033a6111977d28bd7 performed during patch assembly.
- Run `swift test --package-path VEILOPOLY_DEV/Veilopoly --filter RoomLinkPolicyTests` (new pure package tests); run existing `VeilopolyNetTests`.
- Xcode/iOS target: `VeilopolyInvitationBridgeTests.testQuietButAuthenticatedPeerDoesNotForceGameOffline`, all other invitation suites, `BLETransportSafetyTests`, `BLELinkReliabilityPolicyTests`, and full regression build.
- Review source diff and run `git apply --check` before integration; Apple SDK not available in the staging environment.

## Two-phone matrix (must execute on actual devices)
1. Both directions active; idle >15 seconds with secure session stable: BOTH still report connected, status may show a lightweight sync probe.
2. 20–60 seconds with one direction losing control packets: no forced PHY disconnect; game sequence/hash eventually resynchronizes.
3. RSSI strong/good/marginal/weak: no RSSI-triggered disconnect. Verify adaptive burst settings do not starve control/voice.
4. Make CBPeripheralManager.updateValue return false; ready callback delayed/missed; 250 ms fallback resumes queued data without loop or data loss.
5. GATT discovery/notification >45 seconds with PHY connected: stays PHY_CONNECTED, retries discovery in place; never advertises false GATT_READY.
6. Real OS didDisconnect / user explicit disconnect / peer leave / auth rejection: still pause/stop as appropriate.
7. Both orientations of central/peripheral role, foreground/background transition, LAN secure failover, concurrent file+game+voice traffic.
8. Byte-for-byte room-state hashes, no duplicate commands, no dropped or reordered final accepted messages; test device lock/suspend conditions.
9. Monitor queue depth, p50/p95 control latency, actual throughput and battery/thermal impact before claiming speed improvements.
