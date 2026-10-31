# Acceptance tests
1. Verify official ZIP SHA256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`; all 12 engine files untouched.
2. Run `swiftc VeilLink/Narrative/VeilMonogatariByteRange.swift Tools/VNPort/tests/swift/main.swift -o /tmp/vnrange && /tmp/vnrange` (15 cases).
3. Independently extract user-provided R3 ZIP after matching SHA256, review complete host Swift, JS, and real vendor tree; do not treat this PR as shipping the complete game.
4. On isolated integration branch: add full source+resources, check XcodeGen **folder** Copy Resources layout, iOS15 build and XCTest.
5. On iPhone7/iOS15.8.3: storage across relaunch; normal/ranged media requests; memory, tap and crash/reload tests; dark/light and VoiceOver.
6. No IPA or main promotion until Governor P0 gates and owner release authorization.
