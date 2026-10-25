# Security and integration risk

- **Dependency compatibility**: upstream SwiftSoup 2.14.3 uses Swift tools 6.0; select pinned 2.9.6 for current Swift 5.9. This version has not been verified with XcodeGen/macOS iOS SDK in this session.
- **Untrusted HTML**: parser is not an HTML security sandbox. We never load URLs or render HTML in WebKit; SwiftSoup is used to produce only text and inert http/https link strings. URLComponents link checks reject credentials and control characters. No browser navigation.
- **Expensive input**: 512 KiB HTML can still be very deeply nested. Parsing runs off-main, but SwiftSoup runtime/CPU/memory benchmark on A10 hardware is mandatory. Output and search are bounded. Loading file first checks metadata, then actual content length.
- **Encoding**: currently only UTF8 and BOM UTF16 supported; Chinese GBK/GB18030 exported HTML will show a clear unsupported-encoding error, not corrupted garbage. Add more encodings later with explicit sniffing safeguards.
- **Data lifecycle**: reading takes place only after user picks a local file, no database persistence, cache or external upload. UI clears on disappearance. OS file provider may sync that source file through its own service; the app does not initiate remote access.
- **SwiftUI concurrency**: UI `Task.detached` transport of URL and pure Sendable parsed results requires real iOS SDK strict Swift concurrency build review.
- **Shared-file conflicts**: `project.yml` shared with CodeScanner PR #84 and other agents; `ToolCenterView.swift` shared with #67/#68/#70/#72/#76 and many feature lanes. Governor must manually combine only accepted integrations.
- **Urgent P0**: pre-consent startup, lost Keychain access and iPhone7 global gesture regression PR #64/#65/#66 supersede optional enhancements. No main change or release until those are stabilized.
