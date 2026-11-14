# E1 verification gates

- [x] Verified exact source anchors on main@ccafebab147e069fbabfff579dbf323b0d54f191; source-only patch generated.
- [x] No product-tree commits, protected protocol changes or release actions.
- [ ] `git apply --check` on Governor integration branch: NOT_RUN
- [ ] Xcode compile, BLETransportSafetyTests: NOT_RUN
- [ ] Two physical devices: NOT_RUN
  - Pair/connect and send control/text/image traffic.
  - Repeatedly call start() while connected; verify queues and active link persist.
  - Toggle BLE power off/on; reconnect, scan resumes once CoreBluetooth reports poweredOn.
  - Background/foreground transitions: existing restore/scanning behavior remains correct.
  - Connect/disconnect a Bluetooth headset during mesh transfer; no guarantees until measured.
  - Record Instruments Energy Log, BLE scanning, reconnect count and RSSI updates before/after patch.
- [ ] CI + simulator package: NOT_RUN
