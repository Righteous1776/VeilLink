# E1 risks / Governor arbitration
- **File-level overlap with PR #137** (BLETransport reconnect damping and telemetry); do not automatically concatenate into that PR.
- Routing notification on secondary thread is explicitly shifted to @MainActor via Task; Swift 6 actor/sendability compiler verification is pending.
- Peripherals found only through repeated advertisements may have stale RSSI when a headset is connected. Existing connection RSSI and foreground resume retain recovery; user-visible scan strength may be less current.
- AVAudioSession changing categories may transiently switch HFP/A2DP. This mitigates extra scan work, NOT audio codec, OS radio coexistence or route interruption recovery.
- No automatic fallback of audio output to loudspeaker; privacy-preserving iOS route rules remain OS-owned.
- No new multithread Bluetooth radio claims. Full iOS SDK / device / power instrumentation NOT_RUN.
- No main changes or release/build/workflow dispatch.
