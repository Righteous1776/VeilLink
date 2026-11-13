# Overlap and risks

- **High overlap** with Draft PR #186, which also edits GomokuBot and LocalAIGameController. Merge authority belongs to VEILLINK-IG-001. Do not apply either proposed patch blindly; maintain one safety gate and one decision head.
- Current external JSCore engine has no streaming depth/PV interface. Real live external search telemetry requires separate code and JSC/actor concurrency review.
- Two full sequential searches could roughly double latency, defeating user experience. Split one fixed budget or use protected concurrency; test on real hardware.
- Candidate-level fusion is not shared-tree fusion; PVS/VCF remains an advisor, not a second independently authorized final arbiter.
- Scores from different search implementations have different units and are NOT directly comparable.
- Rendering animation without real events, or generating artificial 'thinking' / percentages, is explicitly forbidden by this proposal.
- Private user training records must not be committed to the repository. Historical HTML prototype lives outside GitHub and is clearly a replay.
- **Status**: Only governance Inbox files were changed. No merged app feature, Xcode test, packaged IPA, or verified win-rate gain.
