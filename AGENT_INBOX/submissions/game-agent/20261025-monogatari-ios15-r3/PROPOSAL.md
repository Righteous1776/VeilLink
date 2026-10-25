# Full official Monogatari v2.8.0: iOS15 reliability R3
Owner requested additional optimization after R2 full upstream binary import.
This PR stages an actual **Foundation byte-range parser** plus 15-scenario executable test in FILES/PATCH.diff.
The complete user-facing R3 ZIP contains remaining modified **native SwiftUI/WebKit source, full unmodified upstream engine, source vendor, 94-file package**, original official release ZIP, iOS host adapter and all validation programs. Those additional sources and binary assets are **not** stored in this GitHub Inbox proposal, and must be ingested separately by Governor.

R3 candidate improvements: 256-KiB bounded asset streaming, single Range 206 / invalid 416, path+size guards, WebContent process termination manual recovery, init-failure handling, current-session LocalStorage availability warning, de-duplicate/allowlist JS->native messages, disable debug JS execution (while retaining debug.js bytes) and disable eager preload.

Current tests: exact official archive 2,798,775 bytes SHA match, 56 source files retained, all 12 upstream engine blobs unchanged, 15 Swift Foundation range tests PASS, 19 story nodes / 4 endings PASS, bridge+error tests PASS, fake integration checkout dry-run/apply PASS, source-only patch apply check PASS. Not Apple SDK or physical device tests.

Priority: Resolve iPhone7 P0 touch/signing and #64 #65 #66 before product promotion. No direct change to chat/SQLite/Keychain/BLE/wire/A9/A10.
