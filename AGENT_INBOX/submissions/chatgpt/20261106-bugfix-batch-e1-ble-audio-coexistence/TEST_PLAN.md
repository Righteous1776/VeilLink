# E1 validation plan
- [x] Source anchors matched unique main@ccafebab147e069fbabfff579dbf323b0d54f191; scoped patch only.
- [ ] Apple SDK parse/build/XCTest: NOT_RUN.
- [ ] Headphones A2DP music + BLE chat, headset HFP PTT + BLE chat, wired audio control, headset connect/disconnect mid-message.
- [ ] Verify `CBCentralManager.isScanning` stays true in background, repeat discovery coalesces; authenticated links remain intact.
- [ ] Verify route changes immediately adjust scan policy, no crash while PTT or recorder is active.
- [ ] BLE message, images, encrypted packet, GATT watchdog/reconnect, RSSI filtering and app resume regression.
- [ ] Capture energy log (CPU wakeups, BLE radio, scan callbacks, RSSI requests) comparing before/after 10–30 min.
- [ ] Test device combinations: iPhone + AirPods/third-party HFP, iPad, LAN and BLE simultaneous; OS permission changes.
- [ ] Compare behavior with #137 reconnect damping, #138 image size limit and #130 game recovery before integration.
