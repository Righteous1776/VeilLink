# R1 verification: performed vs required

**Performed in this environment (Swift 6.2.1, Linux x86_64):**
- `swiftc -swift-version 5 -O` compiled & executed `SessionMachineSmoke.swift` with checks active via `precondition`: role/consent handshake, early frame rejection, READY/ACK, replay/stale/expiration, wrong peer UUID, revocation.
- `swiftc -swift-version 5 -O` compiled & executed `WireSchedulerSmoke.swift`: 64-bit near-max frame ID, out-of-order roundtrip, duplicate replay rejection, queue-full peek invariance, newest waiting replacement, stop clears buffers.
- `swiftc -swift-version 5 -O` compiled & executed `WorkflowSmoke.swift`: two mocked peers, invite/accept/system picker callback/READY-ACK/first-frame/stale/STOP. Network was MOCKED; image display NOT decoded on device.
- `swiftc -frontend -parse` syntax-checked the SwiftUI component, gallery and XCTest file. **Not** an Apple SwiftUI typecheck or Xcode compile.
- `PATCH.diff` is advisory add-only. Apply against fresh main in a Governor integration branch after product wire/app source review.

**Not performed:** iOS SDK type checking, SwiftUI layout render, native XCTest, SCContentSharingPicker/SCK audio exclusion, actual Bluetooth hardware, replay/AEAD security review, user consent UI on Apple, background continuity, IPA build, release, Apple signing. All are mandatory before merge to product.

**Additional regression matrix:** 60s invites; duplicate accept/decline/READY; wrong peer/UUID; queue floods and burst loss; frame replay, partial/torn JPEG, 32KiB boundary, UInt64 wrap terminal; orientation/dynamic type/VoiceOver; 10/30-minute Bluetooth-only two-phone tests; no persistence via SQLite / backups / exports / blackbox; “close” while sender backgrounded; device lock/notification overlay; text readability at 1/3/6/12 KiB/s; chat control latency under screen traffic.

Run bundled tests: `bash LOCAL_SMOKE/run.sh` on a Linux or macOS environment with Swift 6.2+ installed. The demo `PREVIEW/VeilScreen_R1_UI_Demo.html` is an **interface-only** offline clickable mock, not a functioning communication client.
