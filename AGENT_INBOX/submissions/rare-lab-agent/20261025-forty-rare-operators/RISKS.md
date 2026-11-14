# Risk register

1. **Overlap:** Earlier PR #67/68 used the name `VeilMissionControlEngine` for distinct 20-feature systems. RareLab uses new `VeilRareLab*` type names and independent source files; only proposed `ToolCenterView` entry may require a manual three-way merge. Do not concatenate unrelated patches.
2. **Current incidents:** PR #64/#65/#66 gesture and startup P0 must be integrated and tested before UI expansion. This branch is staging-only, no product source writes.
3. **Truthfulness:** All values derive solely from user-entered JSON. RSSI, topology, trust, signer and touch metrics are advisory, not a measurement or proof. Algorithms never initiate BLE, modify signing, open sqlite or rekey.
4. **Security:** Data max 64KB; JSON sample should contain anonymous labels/tech-only values. The UI has an explicit warning not to input keys, real QR secrets, messages or private data. Copying output elsewhere is user-initiated.
5. **Validation:** Linux XCTest is not equivalent to iOS Xcode build, and the UI is only syntax-parsed; iPhone7 iOS15 memory and touch need physical validation.
6. **Algorithm limits:** Graph edge count 512, event count 2000 and numeric array length 4096. O(V*(V+E)) articulation/bridge analysis can be heavier on old devices; require benchmarking and may cap graph size further.
7. **Diagnostics:** Causal language strictly avoided for RF and UI patterns. Consent/signer continuity checks compare version labels; they do not establish cryptographic identity or key recovery.
8. **No release authority:** No workflow_dispatch, main merge, IPA packaging or version/build metadata change.
