# Risks and overlaps

- MAJOR: R1's ScreenCaptureKit-first plan is incompatible with iOS 15 full-screen streaming; use iOS 26 ReplayKit Upload extension, iOS 27+ SCK follow-up.
- MAJOR: Separate ReplayKit extension may capture in background even while host's BLE poll loop is suspended. TrollStore "true background" is not an API contract. No live-background guarantee without actual two-device trials.
- MAJOR: New signed Broadcast Upload extension + shared App Group / Keychain entitlement might not be supported by current signing pipeline, especially unsigned IPA and sideload/TrollStore installation; no signed distribution claim.
- MAJOR: Does not wire core SessionCoordinator AEAD or WireKind; `offerMediaToTransport` is dependency-injected. Integrator must reject any plaintext BLE path, cross-peer session, nonconsensual launch or persistence.
- Privacy: App Group encrypted transient ciphertext lives in a replaceable file. It IS disk IPC (and may be in OS storage snapshots), not pure RAM, even though not retained as a recording. User must understand any visible screen content may be shared.
- Performance: grayscale JPEG 240-540px is visually unproven; unreadable characters require ROI/tile improvement. Video encoding in ReplayKit extension still needs device CPU/thermal benchmarks.
- Concurrency: off-main mailbox read/Keychain operations, with session+generation checks, mitigate UI stalls but App Group atomic replace/delete is lossy by design. Need signed-device stress and Swift strict concurrency checks.
- Repository overlap: R1 PR #232 owns chat+UI/state; R0 PR #226 includes incompatible wire v1; diagnostics, BLE, AppModel, project.yml, Info.plist and protocol surfaces are protected and subject to Governor arbitration.
- Tests: Linux route/100-frame PASS ≠ iOS framework compile/pass ≠ actual BLE screen sharing.

- R2.1: Important compiler correction: original BroadcastUploadHandler used `[String: NSCoding]?` instead of `[String: NSObject]?`; fixed in candidate. Needs Xcode SDK override check.
- iOS15 device-specific broadcast target registration, signing, memory pressure, BLE background polling are not verified.
