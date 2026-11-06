# Tests
- [x] All 5 proposed file diffs mechanically round-tripped onto unchanged main ccafebab147e069fbabfff579dbf323b0d54f191.
- [ ] XcodeGen, xcodebuild, complete XCTest on Apple iOS 15+ SDK: NOT_RUN.
- [ ] BLE photo transfers at 1KB/200KB/250KB/384KB; verify no uploaded attachment >384000B and no 3MB route leakage.
- [ ] LAN to BLE switch while image being encoded and during 48KiB checkpointed transfer; ensure previous LAN attachment stays queued and does not transmit on BLE.
- [ ] BLE screenshot with 10pt Chinese/Japanese text and QR, transparency PNG; image human/SSIM comparison and explicit error if cannot fit.
- [ ] BLE headset + PTT and image simultaneously, weak RSSI, low memory, resume/cancel cycles, 2 iPhone field test.
- [ ] End-to-end elapsed/CPU/energy comparison on real devices; never equate size saving with measured speed.
- [ ] Governor arbitrate overlapping #138 #152 #153 and preserve their non-conflicting tests.
