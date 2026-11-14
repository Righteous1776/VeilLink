# [INTEGRATION-GOVERNOR] Concurrent Fabric V1 — static reconciliation candidate

## Source of truth
- Current exact main: `ccafebab147e069fbabfff579dbf323b0d54f191`.
- Upstream proposals: #150 (AVAudioSession owner/voice/PTT), #149 (priority burst/maintenance/5+1), #146 (BLE radio coexistence). These are all **Inbox-only Draft PRs** and do not change product source.
- #137 (diagnostic log / BLE reconnect damping) is separately deferred: multiple changes to BLETransport, maintenance and link stability; no silent source fusion.

## Non-destructive proposed application order
1. Take #150 audio lease/voice/PTT changes and corresponding audio-lease XCTest.
2. Take #149 **only** core scheduler, BLE queue pacing, maintenance policy and BLE scheduler XCTest.
   - *Do not repeat* #149 PTT `finishReceiving`: #150 has both engine stop and session lease release.
   - Preserve #149 five logical lane test in `VoiceAndPTTTests` by appending alongside #150's lease test.
3. Take #146 BLE audio-route detection, deduplicated scanning, background RSSI suppression; retain its test in `BLETransportSafetyTests` alongside #149's scheduler tests.
4. **Review fix:** `CBCentralManager.scanForPeripherals` may not reconfigure an active scan's allow-duplicates option; upon an actual policy change, stopScan then restart filtered service scan. Do not stop authenticated GATT links or teardown transports.

## Observed verification (not simulation/device claims)
- Applied **34 nonoverlapping diff hunks** in a detached text snapshot.
- Omitted three overlapping hunks: #149 PTT duplicate, #149 voice XCTest insertion, #146 BLE XCTest insertion. Reinstated both distinct tests without duplicate body.
- Original immutable main compared to staged final snapshot generated **33 unified diff hunks** in 6 source/test files.
- Reapplied newly authored PATCH.diff to untouched main snapshot; byte-for-byte matches staged result on all 6 files.
- Swift compiler, XCTest, iOS app build, BLE headset, iPhone/iPad and energy profiling **NOT_RUN**. No production behavior is certified.

## Integration gate
Governor must verify #137 against this candidate, inspect AVAudioSession interruption/route ownership, perform platform build + XCTest and 2-device BLE/PTT/media stress. Only after an authorized integration window should a dedicated integration branch be populated and later promoted to main. **No live-lane or release grant inferred from a short “开始” message.**
