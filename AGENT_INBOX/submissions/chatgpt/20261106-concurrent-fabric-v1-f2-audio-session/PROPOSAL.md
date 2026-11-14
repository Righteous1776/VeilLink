# VL-CONCURRENT-FABRIC-V1 — Phase F2

This candidate adds real process-wide audio-session *ownership arbitration* to the existing 5+1 proposal. `AVAudioSession` is global for the process. The voice recorder, voice message player, PTT capture and PTT receive currently call `setCategory` and `setActive` independently, causing route changes and interference.

- `VeilAudioSessionArbiter` operates on MainActor, grants one owner UUID at a time, preserving existing capture/voiceChat modes and allowing system-selected output routing for message playback. It does NOT allocate extra iOS hardware channels.
- Recorder and player acquire and release ownership on start, stop, completion and error, and correctly release when a previous voice message player is preempted by a new voice message player.
- PTT capture/receive claim same global lease; cancel/finish/reception completion release ownership. Avoid invalid removeTap on uninstalled capture tap; ignore late microphone grant after user cancels preparation.
- PTT receive finishing also stops its playback engine to reduce idle work. This last source hunk overlaps phase F1 PR #149 and must be resolved by the Governor, NOT blindly auto-applied.
- Pure unit test exercises isolation of competing lease owners, not hardware.

**Important:** F2 intentionally refuses incompatible overlapping audio activities rather than mutating a live competing AVAudioSession. UI wording and interruption/route notification recovery still require device acceptance. BLE coexistence remains OS-managed.
