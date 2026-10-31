# Proposal — calm tab transitions and compact the phone chrome

## Evidence

The supplied 4.21-second iPhone recording was sampled at two points. It shows a concentrated shard burst after changing bottom tabs, large navigation titles occupying a second vertical tier below the toolbar, and full-width row separators between individually outlined conversation cards.

## Corrections

### Tab particles

The root particle event token currently includes `model.selectedSection.rawValue`. Every tab selection therefore triggers the modifier's burst path. The candidate removes only that field from the event token. Legal-consent, onboarding and lock-root transitions may still emit a burst; ambient rendering remains governed by `VeilParticlePerformancePolicy`, including the existing God Mode cinematic override.

### Top-level titles

The phone root applies `.navigationBarTitleDisplayMode(.inline)` to chat, nearby, games and settings. Agent already uses inline mode. This keeps all five primary pages in one compact top bar and removes the large empty band seen under the status/toolbar row. Tablet and alternative root themes are unchanged.

### Conversation list density

The list-row modifiers were attached inside `ConversationRow`, below the `NavigationLink` or `Button` that is the actual `List` child. As a result, the outer row could retain system insets/separator behavior. The candidate attaches a shared `ConversationListRowChrome` modifier to both real row containers, hides the system separator there, sets transparent row background, and uses two-point top/bottom insets. The redundant inner padding/modifiers are removed. Swipe actions, context menus and navigation remain attached to the same row.

## Compatibility boundary

- No animation budget, performance override, haptic, data or navigation destination changes.
- No protocol/schema/storage changes.
- No direct edit to `GameLobbyView.swift`, so PR #100's Monogatari integration patch does not have a file conflict.
