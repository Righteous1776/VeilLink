# Test Plan

## Static inspection completed
- All six source paths were read from exact `main` commit `af3d823546c288169d19cb3033a6111977d28bd7`.
- Exact replacements were uniquely matched, with generated unified diff contexts.
- No code executed, no test suite or iOS device available in this connector execution.

## Unit regression (proposed)
- `BLELinkReliabilityPolicyTests.testQueueStallDoesNotDestroyLiveGATTSessionRegardlessOfSignalQuality`
  - live PHY + GATT => `probeLiveChannel`
  - live PHY + GATT pending => `awaitGATTRecovery`
  - OS-disconnected PHY => `recycleAfterSystemDisconnect` even with stale GATT flag
- `BLELinkSnapshotTests.testTransportStageDistinguishesPhysicalFromGATTReadiness`
  - PHY_CONNECTED is physically alive but not secure-routing ready
  - no false `isRecovering` state while GATT negotiates.

## Required integration/device acceptance
1. Two iPhones, both display `PHY_CONNECTED` during negotiation, then `GATT_READY` after subscribe; verify mutual Hello/trust and encrypted duplex messaging.
2. Physically connected peer with artificially paused TX readiness for >16 s: no `cancelPeripheralConnection`, no `onDisconnected`, queued packets remain, subsequent readiness drains them in order.
3. Peripheral notify backpressure lasting several seconds: missed/late `peripheralManagerIsReady` recovers via periodic 400 ms safety probe; no duplicate packets.
4. Actual radio disconnect, Bluetooth-off, background, app restart: callbacks transition to recovery, exponential reconnect works, and persistent outbox eventually retries.
5. Weak RSSI through moving apart, headset audio coexistence, two devices with simultaneous central/peripheral roles; verify no "soft" disconnect from quality score alone.
6. Measure p50/p95 queue wait, time-to-recovery, packets delivered, battery/thermal against current main; do not claim throughput gains without measurement.
7. Run `xcodebuild` iOS app build, existing BLE and SessionCoordinator XCTest inventory, simulator smoke, real-device stress tests; check no regressions.

## Pass bar
- No premature disconnect on live PHY/GATT.
- No queue loss during live-channel backpressure.
- No false "fully connected" before secure handshake.
- No protocol/security relaxation.
