# Collision and validation risks
- **Collision A: #149 × #150** — PTT finishReceiving engine shutdown duplicated; choose #150 which additionally releases audio lease. The #149 duplicate hunk is omitted.
- **Collision B: #149 × #150** — same VoiceAndPTTTests class introduction; combine two different tests, no duplicate names.
- **Collision C: #149 × #146** — same BLETransportSafetyTests class insertion; combine separate scheduler and headset policy tests.
- **Collision D: #137** — BLETransport reconnection/telemetry overlaps; quarantined for independent arbitration and platform validation.
- **Audio design risk**: exclusive AVAudioSession lease causes PTT inbound to reject if message playback/recording is active; consider product-level preemption UI and interruption/route-change repair before deploying.
- **BLE risk**: stopping and restarting discovery on audio route transitions may briefly delay peer discovery, while keeping already connected GATT links. iOS may enforce its own scan/coalescing policy.
- **Performance risk**: realtime burst bound 8 could increase image transfer latency during PTT; prioritize measured throughput/latency comparison and rollback if necessary.
- **Governance**: PATCH.diff only under this Inbox; no main or product-tree changes, no CI dispatch, no iOS release or IPA, no unapproved live lane.
- All 34+ source hunks were text-applied and the unified diff round-trip verified. Apple platform build, Swift compiler and real device NOT_RUN.
