# R2: Import local HTML articles into VeilLink without executing active content

## Existing state and immediate utility

VeilLink ToolCenter currently has QR, JSON, text, integrity and codecs but no offline HTML file reading. Users can save web articles as standalone HTML files, then open their titles, paragraphs and links in the app without Internet access.

## Proposed implementation

1. Use **SwiftSoup 2.9.6** through XcodeGen's SPM pin `exactVersion: 2.9.6`. The inspected upstream 2.9.6 Package.swift states `swift-tools-version:5.9`, iOS 13+ and no package dependencies. **Latest 2.14.3 requires Swift tools 6.0, so do not install it in Build61 Swift5.9.**
2. New Foundation `VeilHTMLImportPolicy`: max 512 KiB input, UTF8 / BOM UTF16 decoding, 100,000 output chars, 400 sections, 40 inert links and 100 visible search results. Explicit protocol filtering: https/http, no URL credentials, control characters or oversized URLs.
3. `VeilOfflineHTMLImporter`: user-selected security-scoped local file; inspect size before reading, run extraction in background task; use SwiftSoup parse to remove script/style/noscript/template/iframe/embed/form/nav/footer etc. No webview, script execution, network fetch, indexing, database persist or shared cache.
4. `VeilOfflineHTMLReaderView`: Files system picker (HTML/HTM), searchable local SwiftUI paragraphs and manual copy through the existing clipboard safeguard. Exits clear temporary document state and invalidates stale task results.
5. Two XCTest suites: policy 7 methods run independently on Linux, parser 4 methods staged pending SwiftSoup/iOS integration.

## Difference from feature-count catalogs

This proposal adds one real daily utility with end-to-end file picker + local engine + actual reading UI, not a feature count or a new BLE capability. Existing chat/backup/identity/transport untouched.
