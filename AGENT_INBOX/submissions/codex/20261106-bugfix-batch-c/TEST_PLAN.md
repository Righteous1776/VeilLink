# Batch C test plan and execution record

## Performed (source-level)
- PASS: Refreshed repository, verified main still equals ccafebab147e069fbabfff579dbf323b0d54f191.
- PASS: Read repository constitution and Issue #6; confirmed INBOX_ONLY and restricted outputs.
- PASS: Anchored every proposed edit to exactly one original source block at this commit, with no overlapping edit spans.
- PASS: Generated four path-targeted unified-diff sections with calculated old/new hunk line counts.
- PASS (post-submission): Independently replayed all 13 unified-diff hunks against exact main source snapshots in four files; every original context line and old/new line count matched. This is a structural patch-apply check, not a Swift compile, XCTest run, or Apple SDK check.
- PASS (post-submission): PR #139 contains exactly five files under the declared Inbox submission, and main remains identical to the recorded base.
- PASS: Confirmed CREATE TABLE messages uses an ordinary rowid table; no WITHOUT ROWID in its declaration.
- PASS: New XCTest design covers local insertion ordering when UUID-string order opposes saved order, across three database reads.
- NOT_RUN: XCTest and Xcode/iPhoneOS build (no Apple SDK in this environment).
- NOT_RUN: iOS15 device/simulator gestures, physical-device timing, dual-peer ordering.

## Required integration gates
1. Apply PR #137 and #138 as governed; resolve PR #129/#130 overlaps explicitly. Verify `git apply --check PATCH.diff` against original base, then rebase the selected chunks on the integration head after overlap review.
2. `xcodebuild test` with DatabaseStoreTests plus chat/game UI smoke. Validate all target platforms including iOS 15 as applicable.
3. Open 50+ message conversation with hidden latest protocol message: first frame anchors at bottom without moving finger; rapidly reopen twice.
4. Read history 20 messages above bottom, receive new message: scroll position stays. Scroll to bottom and receive another: it follows.
5. Search a message, jump from workspace to older message, and load older history: verify these explicit navigation operations work and are not hijacked.
6. Drag vertically starting in card title/body, buttons, adjacent margin; reach latest messages. Tap CTA, accept, decline, retry; they remain operable.
7. Insert same-millisecond messages with reversed lexical IDs; assert fetchRecentMessages, fetchMessages, and fetchMessageIDs agree on *local insertion order*.
8. Two physically distinct devices each send 10 messages with overlapping sent_at and reconnect out of order; log both displayed sequences. Treat divergence as expected unresolved global-order limitation until consensus contract approved.
9. Record before/after crash rate, main thread stalls, scroll gesture success, time-to-first-bottom. Do not mark device checks passed without logs.
