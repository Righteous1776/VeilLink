# VeilScreen R2.1 — Two iOS 15 devices compatibility note

- Owner-confirmed sender and viewer: iOS 15; do **not** assume iOS26.
- VeilLink root `project.yml` minimum iOS15; this broadcast extension fragment also declares `deploymentTarget: "15.0"`.
- Capture: `ReplayKit.RPSystemBroadcastPickerView` launched by consenting local sender; `RPBroadcastSampleHandler` receives video only. Explicit peer acceptance is separate.
- **Fixed concrete API mismatch**: the correct method is `override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?)`. Original R2 had `[String: NSCoding]?`, which cannot correctly override this ReplayKit method.
- Storage/security: AES-GCM encrypted, single-slot App Group mailbox; per-session shared keychain; no audio and no intentional saved recordings. Temporary ciphertext touches disk.
- BLE: iOS15 supports Core Bluetooth central/peripheral background event handling, but its execution restrictions can suspend the host loop. ReplayKit capture continuing is not proof that media reaches the viewer.
- Targeted verification: iOS15 compile+signed app/extension; picker registration; extension receives video; app reads frame while background; trusted peer receives E2EE frame; graceful stop; 30min continuity and battery/thermal.
- **Not verified:** Xcode/Apple SDK typecheck, signing/entitlements, two-device iOS15 hardware testing, foreground/background BLE transfer.
- Prefer low cadence 2.5s (0.4fps), width 320px and 6KiB frame budget until actual link throughput is measured.
- Neither TrollStore nor app-side signing bypasses Apple's required system screen-recording consent.
