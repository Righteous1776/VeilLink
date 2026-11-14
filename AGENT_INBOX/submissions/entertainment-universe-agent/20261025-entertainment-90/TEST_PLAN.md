# TEST_PLAN

## Executed

1. Local Linux Swift 6.2.1 `swift test -j 2` standalone fixture: **10 XCTest PASS, 0 failures**.
2. Local `git apply --check` + `git apply` for add-only 3-file patch: PASS.
3. Exact 90 feature IDs E01-E90 validated: unique, 9 groups × 10.

## Required before main integration

- Governor `git apply --check` against exact current main and verify new source paths not already present.
- XcodeGen + iOS15 simulator `xcodebuild` and full VeilLink XCTest.
- iPhone7 iOS15.8.3 real-device: consent screen, dark/light cold launches, taps, scrolling, single-hand use, larger text and accessibility, 15-minute memory/thermal loop.
- Real iPhone 13 navigation, background/foreground, no accidental BLE/Keychain/database access.
- Story JSON import security tests (current candidate only has in-memory books): length-limit check before decode, adversarial content, malformed cycle and orphan scene.
- Resolve #64/#65/#66 and overlap with #67/#68; Do not touch ToolCenter in this PR.
- Owner-controlled separate integration and release review. **No workflow dispatch or IPA authorized**.

## Scope caveat

Linux Foundation compilation and 10 PASS do not prove SwiftUI iOS SDK compilation, complete app integration, native XCTest, or device stability. 90 catalog entries have *not* been implemented.
