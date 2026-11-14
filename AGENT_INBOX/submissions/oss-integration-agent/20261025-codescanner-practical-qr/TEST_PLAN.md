# Proposed tests and staged verification

## Completed
- Read exact current main `501ef814a0a9bea41419fe2d9f48315371b30320`, project.yml, Info.plist, remote QR UI, temporary QR text UI and pairing coordinator.
- Read upstream CodeScanner **2.5.2** Package.swift and scanner view initializer from official git tag; selected documented parameters (including `requiresPhotoOutput: false`).
- Independently reconstruct and apply `PATCH.diff` hunks in-memory against exact GitHub main source contexts. **9/9 hunks match** across four old files; no direct product edit.
- Run standalone Foundation `VeilQRScanPolicy.swift` with Linux Swift 6.2.1 / Swift-5 language mode / strict concurrency warnings-as-errors. **10 hand-coded scenarios PASS** (valid Chinese text, newline, proper prefix; length, empty, controls, URL as opaque text). Note: this is not executing bundled XCTest.
- Five XCTest test methods authored under `FILES/VeilQRScanPolicyTests.swift`, **not executed** in iOS XCTest environment.

## Governor integration gates
1. Copy three `FILES/` sources to indicated App/UI/Core and Tests folders; apply `PATCH.diff` on a fresh integration branch with git apply --check. Do not resolve overlapping ToolCenter edits silently.
2. XcodeGen resolves exactly CodeScanner 2.5.2 (no transitive dep), verify official tag and license notice in app third-party acknowledgements.
3. macOS Xcode/iOS15 simulator compile and full XCTest.
4. Physical iPhone 7 iOS15.8.3: tap on temporary QR, grant/deny camera, manual cancel, focus distance, cold app start, dark/light switch, accessibility Dynamic Type and touch gesture non-interference.
5. Two-device display QR -> scan -> text appears unchanged (including Chinese/newlines) **without network**. No auto-open URL or photo persistence.
6. Remote QR scan -> original `consumeQRCode` rejects expired/malformed data, requires configured Relay and two-sided six-digit check; validate QR generation 60s rotation.
7. Failure case: camera denied/damaged QR returns a privacy-safe error, photo-import fallback remains.
8. Check no Keychain reset, no SQLite schema version change, no BLE wire version change, no new background modes, no new release/IPA until P0 gates.

## Hard stop
PR #64/#65/#66 P0 startup/touch incidents unresolved; no product release, IPA workflow, feature integration or main merge without owner/Governor authorization.
