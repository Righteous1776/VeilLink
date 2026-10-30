# Test plan and gate

## Executed
- Pure SwiftPM on Linux Swift 6.2.1: BLEGattHandshakeWatchdogTests, 8 XCTest methods, 0 failures. Tests cover 45s boundary, GATT-ready completion, disconnect, multiple peers, deterministic reporting, stale clock input, fresh reconnect epoch, reset and invalid/duplicate events.

## Required before promotion
1. Apply PATCH.diff to exact Build62 main or governor-selected integration branch. XcodeGen + iOS15-target simulator build + full XCTest (new tests included).
2. **iPhone7 iOS15.8.3 ↔ iPhone13 iOS26** with cellular data/Wi-Fi off (Bluetooth on), both directions: discovery -> PHY_CONNECTED -> GATT_READY -> encrypted hello -> user message -> ACK; verify only one connection event per readiness epoch.
3. Real GATT fail cases: missing service UUID, characteristic missing required props, notify rejected, service discovery callback failure. Verify no app-level 'connected' event and retries are 0.75/1.5/3/6/... with cap 30s (jitter permitted) across transient PHY connects.
4. Suspend/restore, cancel explicit connect while didConnect races, stopped transport, background/foreground, iPhone7 lock screen, Bluetooth power off/on. Expect no ghost messages or unwanted auto-reconnect after user disconnect.
5. 45s timeout with synthetic/mock callback suppression: only pending *wanted* central cancels; passive or ready peripheral role unaffected. Under BT poweroff/radio stress, no repeated cancel storm.
6. Blackbox export: event='ble.gatt_handshake_failure' with phase/attempt and 'ble.gatt_handshake_timeout' only. No conversation text, personally identifying IDs, codes or keys.
7. Regression: BLEFramer, BLETransportSafetyTests, BLELinkReliabilityPolicyTests, BLEConnectionIntentStoreTests, SessionCoordinator end-to-end tests, voice/PTT, BLE/LAN fallback and old-v4 packets.

## Release gate
Do not merge to main or build an IPA until all protected-surface review and physical device proof are supplied.
