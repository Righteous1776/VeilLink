# Validation
- [x] All 8 hunks round-trip against main ccafebab147e069fbabfff579dbf323b0d54f191; source-only, no protected product write.
- [ ] Xcode SDK compile, XCTest on macOS: NOT_RUN.
- [ ] BLE messages 200KB/350KB/500KB/1MB/2.9MB, all <=3MB permitted.
- [ ] LAN->BLE and BLE->LAN fallback preserves original stored attachment bytes and SHA, checkpoint, part indices; no midstream reencode.
- [ ] HEIC/JPEG photos, noisy RAW, screenshots with alpha, small multilingual text, 12MP, orientation, accessibility, thermal/battery.
- [ ] Chat/PTT latency under bulk image, backpressure/ACK recovery with 2 real devices.
- [ ] Arbitration #138/#152/#153/#154 before source integration or IPA.
