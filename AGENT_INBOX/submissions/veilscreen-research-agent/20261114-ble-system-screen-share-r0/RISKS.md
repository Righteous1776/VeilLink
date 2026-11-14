# Risks & overlaps

- R0 is a transmission/encoding prototype, **NOT a working end-to-end screen broadcaster**. No ChatView invitation entry, OS capture adapter or E2EE transport wiring is merged.
- SessionCoordinator, WireCodec, BLETransport and Info.plist are protected surfaces. Governor decides compatible v4 negotiation; must not disable encryption or place pixels in messages/SQLite/backups.
- Existing BLE reliability, diagnostics, chat composer and background continuity lanes overlap. Record collisions; don't silently combine another agent's work.
- iOS26 ScreenCaptureKit API needs Apple SDK/device validation; CoreBluetooth and TrollStore cannot guarantee permanent background execution.
- Pixels reveal whatever appears on screen, including notifications/passwords; explicit system permission and visible stop control required.
- At 240px whole-screen, fine text may be illegible. Device measurements and magnification/ROI needed. Frame compression alone is not a fidelity guarantee.
- CI/XCTest/real Bluetooth not run; app source, version, build, workflows, release, IPA and main remain untouched.
