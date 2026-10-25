# VeilLink Practical R3 — ZIP Backup Preflight

This is a **candidate integration package**, not a released iOS binary.

## Functionality
- A read-only ZIP inspection page that opens **Files → ZIP** without asking for a password.
- Rejects malicious ZIP paths, duplicate/alias entries, symlinks, unsupported payload names, missing backup files, oversized archives, decompression bombs, and corrupt manifest data.
- Reads and CRC-checks the small unencrypted `manifest.json` entry; only displays format version, time, counts and sizes, never user identity or cryptographic material.
- Optional **full streaming CRC** of every file with bounded chunks and no disk extraction.
- Does **not** call restore, touch SQLite/Keychain, decrypt ciphertext, alter live message data, or send requests to the network.
- Includes an *advisory* restore entry gate, requiring Governor signoff and real backup compatibility tests.

## Compatibility
- Uses the existing `ZIPFoundation` dependency already declared in `project.yml` (`from: 0.9.19`); no new third-party packages.
- Matches `BackupManager` current v1/v2 layout and declared limits (200 MiB ZIP; 350 MiB expanded; 10,000 files).
- Swift pure metadata-policy unit tests are executable on Linux with Swift tools 5.9 language mode; ZIPFoundation binary and iOS SwiftUI runtime still need macOS/iPhone7 validation.

## Tests
`SWIFTPM` contains `swift test -j 2` policy tests, 16 XCTest executed/0 failures.
`TESTS/VeilBackupArchiveInspectorTests.swift` contains 5 actual ZIPFoundation integration tests **authored only**, pending iOS integration.

## Files
- `FILES/VeilBackupPreflightPolicy.swift`
- `FILES/VeilBackupArchiveInspector.swift`
- `FILES/VeilBackupPreflightView.swift`
- `TESTS/VeilBackupPreflightPolicyTests.swift`
- `TESTS/VeilBackupArchiveInspectorTests.swift`
- `PATCH.diff`: advisory existing-source navigation + restore-entry gate
- `governance/`: 5 mandatory submission documents, license evidence and validation notes

No IPA Actions, main merge, database migration, Keychain change or release has occurred.
