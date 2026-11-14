# R5 Test Evidence & Required Gate

## Already executed locally

- SwiftPM Foundation engines on Linux Swift 6.2.1, full R4 regression + R5: **90 XCTest / 0 failures**.
- E191: monotonic offset and missed notes, wrong lane, invalid timestamps, early input, background pause/resume, 100 four-district deterministic runs, snapshot rebase and replay.
- E192: 20 daily narratives, 4 named eras, deterministic demand, precondition/transactionality, money/condition bounds, 200 full-20-day seeds and replay import/export.
- 2 SwiftUI views: swiftc -frontend -parse success (syntax only).
- Local 6-file source diff: git apply --check --whitespace=error-all PASS in empty git scratch repo.
- Complete ZIP: 89 members, checksum and integrity PASS.
- GitHub smoke tests are SOURCE ONLY; they require R4 E191 dependency and an actual Xcode test run; not counted separately as executed.

## Mandatory next

1. Verify GitHub PATCH.diff against current exact main, avoid duplicate E191/E192 type names in other Inbox submissions.
2. Import R4 VeilRhythmExpeditionEngine before R5 VeilRhythmLiveConductor; reconcile R4 #78 feature gate vs revised R5 candidate ID.
3. Repoint SwiftPM tests @testable import VeilMegaEngines to actual Xcode app target VeilLink, then run macOS iOS15 simulator XCTest including existing 560+ regressions.
4. Physical iPhone7 iOS15.8.3 and another device: startup legal consent, dark/light, tap latency, gesture capture, foreground/background timer shifts, speaker volume/audio permission status and energy drain.
5. Verify no impacts to chat BLE, identity, Keychain, SQLite, safe rollback after failed/partial import.
6. No IPA/release/tag or main merge until prior gates, owner/governor authorization.
