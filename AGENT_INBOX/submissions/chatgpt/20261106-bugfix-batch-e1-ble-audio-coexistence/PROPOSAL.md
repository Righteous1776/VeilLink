# E1 — 降低 Bluetooth 耳机连接时的 BLE 冗余无线电工作

## Real source findings
- Current `BLETransport.beginScanningIfPossible()` uses AllowDuplicates TRUE for all scans. Apple officially warns about energy cost.
- `BLETransport` polls RSSI during background and foreground, while foreground `refreshLinks()` also reads connected peer RSSI.
- `VeilWalkieTalkieAudioController` and voice recorder use AVAudioSession .playAndRecord with HFP enabled; the radio and iOS audio route are controlled by the OS. Five Swift threads cannot create five independent hardware Bluetooth channels.
- Existing GATT watchdog, durable queue, reconnect intent and transport queue recovery must remain active.

## Proposed implementation
- Observe `AVAudioSession.routeChangeNotification` through a Combine cancellable.
- Classify HFP, A2DP and BLE audio route by port type only (no headphone name or personal identifier).
- When Bluetooth headset route is active, disable repeated peripheral advertisements and optional RSSI polls, while continuing encrypted message transmission, GATT watchdog and queue retry.
- When the app moves to background, retain service-UUID filtered discovery with duplicate coalescing; skip unnecessary RSSI polling. Foreground resumes RSSI and repeated scan discovery only when no Bluetooth audio route.
- Maintain scan config to avoid redundant calls to `scanForPeripherals`; never stop the actual secure connections.
- Add policy unit tests for foreground/background/audio combinations.

## Boundaries
Not a guarantee of Bluetooth audio + BLE simultaneity under all iPhone/earbud combinations. Hardware coexistence is OS-controlled, audio route can still switch and disconnect, and there is no new parallel five-radio subsystem. iOS 26 behavior and supported older iOS must be tested.
