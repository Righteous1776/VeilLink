# Test plan — UI navigation density R1

## Executed here

- Inspected the supplied 1170×2532, 4.21-second, 240-fps screen recording and extracted two representative frames: PASS.
- `git diff --check` on the isolated candidate: PASS.
- Static source checks confirm the root particle token no longer references `selectedSection`.
- Static source checks confirm all four large-title phone roots are overridden to inline mode; Agent already uses inline mode.
- Static source checks confirm both conversation row branches receive `ConversationListRowChrome` at the outer `List` child.

The current execution image has no `swift`, `xcodegen` or `xcodebuild`; no Apple compilation or XCTest result is claimed.

## Required Governor/device gates

1. Replay `PATCH.diff` at the recorded baseline with strict context.
2. Run XcodeGen, iOS 15 build and complete XCTest.
3. iPhone 7 and a modern iPhone: cycle through all five tabs repeatedly; confirm no transition burst, no touch interception and ambient particles remain policy-controlled.
4. Enable God Mode full effects; confirm high-quality ambient rendering remains available but tab selection still does not burst.
5. Verify chat/nearby/game/settings titles share one compact top bar in dark and light appearance.
6. Verify conversation list with zero, one and many conversations: no full-width divider, approximately four-point card gap, swipe actions/context menus/navigation intact.
7. Verify Dynamic Type and VoiceOver do not clip the inline title or conversation content.

Any lost swipe action, clipped title, tab touch regression or reappearing tab burst blocks integration.
