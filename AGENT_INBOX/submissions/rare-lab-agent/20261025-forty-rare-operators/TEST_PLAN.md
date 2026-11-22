# R1 verification & gates

## Completed locally

1. Swift 6.2.1 Linux SwiftPM Foundation module compile — PASS.
2. XCTest executed 8/8 and 0 failures, including all 40 sample operator runs and deterministic reruns — PASS.
3. SwiftUI source front-end parse without iOS SDK — PASS (syntax only).
4. No GitHub Actions/IPA started, and no production-tree writes.

## Governor acceptance matrix

- Confirm `git apply --check` against exact `501ef814a0a9bea41419fe2d9f48315371b30320`; add three source/test files through protected integration lane.
- macOS XcodeGen, iOS 15 compiler and SwiftUI type check; full existing + new XCTest.
- Test iPhone 7 320/375pt narrow layouts, VoiceOver, largest Dynamic Type, deep/dark/light theme switch and ScrollView tap reliability with #64–#66 touch fixes.
- Test all 40 manual JSON analyzers (one result each), malformed JSON, 64KB boundary, schema mismatch, NaN/Inf overflow, graph 512-edge limit, 2000-event limit, 4096-element input limit.
- Ensure no private token/plaintext/Keychain data is read/sent/stored, and no telemetry is enabled implicitly.
- Verify diagnostic suggestions cannot mutate live BLE connection, relay routing, trust records, backup, Keychain, SQLite, A9/A10.
- Replay old device telemetry only with explicit owner-approved anonymized fixtures; device UI must label result as sample analysis.
- Preserve old iPhone7 data and keychain access; NEVER use uninstall/rekey/delete as a test shortcut.
- No version bump/unsigned IPA workflow before release authority.
