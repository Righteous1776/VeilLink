# BLE Link Truth + In-place Queue Recovery (R1)

## Reproduced source-level failure
- `VeilLink/Transport/BLETransport.swift` currently calls `recover(id)` after 10–16 s of stalled **central TX** even while `CBPeripheral.state == .connected` and the GATT notify channel is live. `recover` cancels that link and emits an onDisconnected event. This can produce asymmetric UI/session presence without any CoreBluetooth didDisconnect callback.
- `BLEPeerLinkSnapshot.isRecovering` currently returns true for `PHY_CONNECTED` (still negotiating GATT). NearbyView exposes a manual recover button, which likewise can cancel an in-progress real PHY link.
- On `CBPeripheralManager.updateValue == false`, the peripheral TX queue has only the `peripheralManagerIsReady` callback as its unblock path; it lacks the bounded safety probe already used for central writes.

## Proposed change
1. Explicitly classify a stalled queue using **physical link state** and **GATT readiness**, never RSSI. On a live GATT session, retain all unsent BLE fragments, schedule an in-place drain, and report congestion without emitting disconnect. On a live PHY still awaiting GATT, preserve queued traffic and wait for GATT recovery. Only clear the central queue after an OS-observed PHY disconnect and then use persisted connection intent / existing exponential backoff.
2. Add one 400 ms safety probe when peripheral notifications are backpressured. `CBPeripheralManagerDelegate` readiness remains primary; existing work-item de-duplication avoids stacked timers.
3. Treat `PHY_CONNECTED` as physically alive, **not** as a disconnected/recovering peer. Nearby UI shows the antenna rather than a disconnected icon and does not offer the destructive recover action until PHY is actually gone. `isConnected` remains *data-channel-ready* for secure routing, so no fake success is reported.
4. Add deterministic XCTest assertions for live GATT, intermediate PHY, actual disconnect, and stale-notify flags; strengthen physical-vs-GATT snapshot regression.

## Not in scope
- No MTU, radio transmit power, iOS BLE connection interval, advertising or PHY settings: iOS CoreBluetooth does not expose arbitrary controls for these.
- No wire protocol, encryption, handshake authentication, ACK, persistence, LAN, versions, CI workflows, release, or IPA changes.
- "大风" appears as the user's designation, not an identifiable dedicated BLE source file in the inspected repository; this proposal modifies the shared transport used by all features.

## Integration requirement
Governor must apply this advisory PATCH.diff on a protected integration branch, run iOS Xcode build/XCTest, two-device test, and compare BLE logs before any merge to product main.
