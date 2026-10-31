# Validation and acceptance

## Tests actually performed
- Linux Swift 6.2.1 in Swift package language mode 5.9: policy engine and **7 XCTest passed, 0 failed** for Chinese UTF8, BOM UTF16, empty/oversize/malformed data, URL scheme/credentials/control blocking and bounded local search.
- The importer Swift source and SwiftUI source passed Swift frontend `-parse` (syntax, **not typecheck**).
- Checked upstream official SwiftSoup release 2.9.6 Package.swift and license at GitHub, confirming swift-tools-version 5.9, iOS 13+ and MIT, no dependency list. Observed that 2.14.3 needs Swift 6.0.
- GitHub Inbox `PATCH.diff` has 2 product paths, 3 exact-context-valid hunks based on latest main SHA 501ef814a0a9bea41419fe2d9f48315371b30320; every hunk line count and original context verified independently, LF preserved.

## NOT performed
- No SwiftSoup package resolution or actual third-party parser unit tests here (outbound network unavailable from Linux runtime).
- No SwiftUI iOS SDK typecheck, XcodeGen run, app XCTest, IPA Action or physical iPhone 7 test.
- The staged 4 parser XCTest methods are **authored but not executed**.

## Governor integration gates
1. Reconcile shared `project.yml` and `ToolCenterView.swift` with PR #84 CodeScanner and other Mission/Rare/Aether/Game agent navigation changes on a single integration branch. Do not automatically apply independent diffs verbatim.
2. Pin 2.9.6 and resolve SPM; verify full MIT credit retained in distributed notices and license file.
3. Build iOS15 app with XcodeGen, strict concurrency, all XCTest including parser suite (11 planned methods).
4. iPhone7 iOS15.8.3 import HTML and HTM from local Files and iCloud Drive: permission/revoked/moved file, UTF8 Chinese, UTF16, malformed GBK (graceful error), large file preflight, edited links, fallback body.
5. Ensure malicious scripts, iframes and active resources are never evaluated or loaded; no networking, auto-link tap, arbitrary file write or clipboard copy unless explicitly requested.
6. Run Instruments/memory sampling for 512KiB deeply nested HTML, 400 element sections, rapid file selection/dismissal, dark/light appearance and VoiceOver; fix crashes/hangs before production.
7. Confirm no changes to old Keychain/SQLite identity, pairing, BLE Wire v4, chat history, existing backup and signing; P0 incident PRs #64/#65/#66 remain blocking.
