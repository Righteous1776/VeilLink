# Stage-gated test plan
- [x] main SHA, issue #6, 146/149/150 heads/draft states verified; no main drift.
- [x] 34 source/test hunks applied on text copy; 3 collisions explicitly triaged; composite generated and round-trip re-applied exactly.
- [ ] On authorized integration branch run `git apply --check` for this single composite diff and `git diff --check`.
- [ ] `xcodebuild` iPhone simulator build, Swift 6 strict checks, `xcodebuild test` focused: BLETransportSafetyTests, VoiceAndPTTTests, BLELinkReliabilityPolicyTests, audio interruption tests; full project suite.
- [ ] Real device A2DP music + BLE authenticated chats; HFP PTT + simultaneous control packets; mid-message headset connect/disconnect; BLE RSSI scanning active in background; route changes do not break links.
- [ ] Controlled tests 30 minutes idle/connected/image transfer/PTT: CPU wakeups, BLE scan callbacks, power, first-audio-frame latency, UI responsiveness, app relaunch, file-outbox durability.
- [ ] Review #137 reconnect damping, PR #138 media transfer, #145 startup and #147 bounded import for later batch, not automatic this one.
- [ ] CI/XCTest/device gate and governor approval before main or IPA.
