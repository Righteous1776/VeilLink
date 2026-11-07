# D1A validation plan
- Static anchors and proposed diff verified against ccafebab147e069fbabfff579dbf323b0d54f191; three files changed by patch only.
- XCTest tests proposed for: staged UTF8 text roundtrip, rejecting .pdf/.zip/.sh/.exe, invalid UTF8, oversized >16KiB text.
- Manual Files UI: iCloud/local TXT + MD + JSON + CSV -> draft without auto-send; image -> original ImageTranscoder route. Unknown file -> explicit unsupported alert. Check originals never deleted.
- Integrator must apply PR #129 file cleanup before/with this patch to avoid orphan UUID lease directories on image path.
- Cross-PR reconciliation: #138 changes same ChatView (route caps); #139 alters ChatView scroll; merge hunks with conflict review, never naive sequence without tests.
- iOS15 and iOS26 UI, Keychain locked, slow iCloud provider, cancellation, relaunch, large input; XCTest on macOS required.
- XCTest, Xcode, Apple SDK, real devices: NOT_RUN.
- General binary file transfer: NOT_IMPLEMENTED; do not mark issue ⑨ PASS.
