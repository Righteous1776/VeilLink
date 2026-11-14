# V4 graceful BLE image validation gates
- [x] Main SHA ccafebab147e069fbabfff579dbf323b0d54f191 and governance checked; candidate modifications generated from immutable main + audited V3 source proposal. No changes to SessionCoordinator.
- [ ] Apple Xcode build and full XCTest: NOT_RUN. No workflow/IPA dispatch in INBOX_ONLY.
- [ ] JPEG/HEIC source 100KB, 200KB, 350KB, 500KB, 1.5MB, 2.9MB. Compression should try to reach 200KB or below 384KB, but any supported result <=3MB must remain sendable on BLE.
- [ ] Transparent PNG and Chinese/Japanese text screenshot: alpha, font legibility, orientation and color profiles. Under-budget quality preservation before scaling.
- [ ] BLE→LAN→BLE during attachment progress: original payload hash, chunk count and checkpoint never change; no oversized-image rejection at 384KB and no endless queueing for LAN.
- [ ] CoreBluetooth constrained route: PTT simultaneous, low RSSI, background/foreground, queue backpressure, pause/resume/cancel; compare actual transfer duration, p95 and battery.
- [ ] Check protocol true 3MB maximum and older iOS decoding, unsupported MIME rejection unchanged.
- [ ] Governor review #138 #152 #153 #154 overlapping code. Disallow stacking competing compression algorithms.
