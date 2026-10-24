# Test Plan

## Static checks

1. Apply the advisory patch on an Integration Governor-controlled integration branch based on the recorded base or a reviewed descendant.
2. Confirm the product diff touches only `VeilLink/UI/ConversationViews.swift`.
3. Build with the repository's strict-concurrency settings.
4. Search build logs for:
   - `ConversationViews.swift`
   - `captured var 'effectiveLimit'`
   - `effectiveLimit`
5. Acceptance requires the line-731 mutable-capture warning to disappear.
6. Do not fail this task merely because the existing DatabaseStore non-Sendable warnings remain; those are out of scope and should be tracked independently.

## Unit tests

Run the full `VeilLinkTests` suite.

Focused existing coverage:
- `DatabaseStoreTests.testRecentMessagePageBoundsNormalChatHistory`
- related `DatabaseStoreTests` recent-page assertions
- `DevicePerformancePolicyTests` for message-window initial/increment/maximum profiles
- `MiniGameTests` session reconstruction and replay tests

No test-source changes are proposed.

## Integration tests

On iOS Simulator:

1. Open a conversation with fewer messages than the initial message window.
2. Open a conversation with more messages than the initial window and use “load older” behavior.
3. Verify `messageWindowLimit` never decreases.
4. Verify loading older messages still respects `messageWindowMaximum`.
5. Build a chat history where a mini-game session command appears in the recent page but its invite lies just outside the initial page.
6. Confirm the loader expands the window until the invite is included or the configured maximum is reached.
7. Confirm the reconstructed mini-game session matches the pre-patch behavior.
8. Trigger rapid reloads so generation cancellation/staleness protection is exercised.

## Negative / failure cases

- `loadAll == true`: confirm all messages load and `messageWindowLimit` is not rewritten by the snapshot.
- `page.hasOlder == false`: no unnecessary window growth.
- unresolved mini-game session history at maximum window: confirm loop terminates at `messageWindowMaximum`.
- multiple quick reloads: stale generation must still be ignored on the main queue.
- low-tier device profile: confirm small increments and lower maximum remain unchanged.

## Regression invariants

- Fetch order and filtering are unchanged.
- `messageWindowLimit` remains monotonic through `max(messageWindowLimit, resolvedLimit)`.
- Mini-game invite/session completeness logic is unchanged.
- No UI state is updated on the background queue.
- No DatabaseStore API or concurrency contract changes.
- No storage/schema/protocol/security/A9/A10 behavior changes.

## Device / OS coverage

Minimum:
- repository CI Simulator/Xcode version;
- iOS 15 compatibility build.

Preferred smoke coverage:
- iPhone 7-class profile;
- one current iPhone profile.
