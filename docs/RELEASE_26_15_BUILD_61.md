# VeilLink 26.15 · Build 61 — iOS 15 Pre-Consent Diagnostics

P0 diagnostic hotfix for the first-use legal signing gate, primarily iPhone 7 on iOS 15.8.3.

## What ships
- Independent, bounded pre-consent black box: maximum 128 allow-listed events, persisted across force-quit/relaunch in app support.
- Explicit **导出临时黑匣子** action available on the onboarding and legal gate before consent is signed, using a normal iOS 15 share sheet.
- Captures startup, scene transitions, theme and color mode changes, legal page/display events, confirmation taps, acknowledgment field focus and sign attempt / invalid input / saved consent / storage failure.
- Exports JSON locally, on deliberate user action. No network upload, app-model or database initialization, Keychain data, raw text or private messages. Export errors do not block signature.
- Added three deterministic XCTest cases for schema privacy, persistence/retention and export without AppModel initialization.
- Preserves all features of 26.14 Build 60, including Wire v4-compatible R1–R5 and SQLite v10.

## Important limitations
The owner's observed Light-mode/cold-relaunch improvement is a reproduction clue, **not a proven root-cause fix**. Physical iPhone 7 UI hit-testing, dark-mode/IME behavior, startup traces, old-database migration and BLE/LAN compatibility still need separate real-device validation. Diagnostics can only capture events after app code starts; early process failures and iOS crashes may leave no trace. Pre-consent data remains local.

This Release is an **unsigned Core IPA**. Standard devices require Apple-issued signing/provisioning; the package by itself is not proof of installability. Prior v26.14-b60 is retained as rollback.

## Validation
Official status must be read from the exact-head GitHub Actions results: iOS 15 simulator compilation, full XCTest, Release iPhoneOS build, package integrity, size/source isolation, SHA256 and release provenance. Publication is blocked unless the complete GitHub Actions release workflow succeeds.
