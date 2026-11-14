# Risks
- No previous local-match persistence exists: already lost positions cannot be reconstructed from AI training history.
- JSON replay+atomic save on MainActor after each accepted move needs p95 latency and thermal benchmark on iPhone7.
- Long 5000-ply Xiangqi record replay and validation may be expensive; bound file size 1MB and test device performance.
- Saving terminal positions and training outcome is not atomic across both independent archives; a crash between the two may leave training statistics incomplete, but board remains recoverable.
- Explicit restart is allowed to remove active match; no onDisappear or mere close may do that.
- In formation teaching mode, stale view state after recording finishes requires UI regression gate before integration.
- Main and sources unaffected; only draft code in Inbox, no signing, release or IPA.
