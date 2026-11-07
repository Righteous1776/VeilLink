# F1 risks
- **Overlaps #137 and #146** in BLETransport.swift, scheduling / BLE headset coexistence. Do NOT auto-apply with either proposal; Governor to reconcile.
- Explicit packet burst bound may reduce throughput during concurrent PTT; actual behavior depends on device ATT MTU and CoreBluetooth timing. No performance claim until measurement.
- PTT playbackEngine stop/restart may add first-frame startup latency after every talk. Needs hardware verification; if regression, revert only this candidate hunk.
- App-level AVAudioSession ownership is not yet solved; F2 is mandatory before claiming headset coexistence fixed.
- No protocol/schema/security changes, product tree edits, workflows, build, IPA, signing, merge or release. Xcode/XCTest/devices NOT_RUN.
