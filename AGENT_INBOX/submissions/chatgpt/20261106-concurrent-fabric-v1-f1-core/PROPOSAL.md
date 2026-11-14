# VL-CONCURRENT-FABRIC-V1 — F1 可执行基础

## Main 实际状况
Current BLE already uses distinct control/realtime/bulk packet queues with priority and control capacity reservation. SQLite already serializes writes on a private queue. iOS AVAudioEngine manages real audio callbacks; there is no value in pinning five OS threads.

## Proposed source modifications
1. Define five logical responsibilities + existing storage serial queue label as 5+1 topology, WITHOUT creating fixed threads.
2. Extract the BLE maintenance cadence into a pure testable policy, preserving foreground/background values.
3. Limit a single BLE burst to eight packets while realtime frames are queued; control remains first, realtime second, bulk last. Do not change wire format, retry, queued packet contents, or link authentication.
4. Stop the PTT receive playback engine when an incoming talk finishes (previously only timer/metrics/state were reset).
5. Add focused XCTest cases for topology, pacing, and unchanged maintenance cadence.

**Implementation boundary**: This is phase F1 only. It does NOT yet implement a shared audio-session owner across PTT and message recorder, generic file transmission, or five independent radio paths. F2 shall handle audio ownership/route-change, F3 integration with #137/#146 and power instrumentation.
