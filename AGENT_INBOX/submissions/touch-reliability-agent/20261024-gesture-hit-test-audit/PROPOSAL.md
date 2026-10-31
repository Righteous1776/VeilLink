# Deeper touch/gesture regression audit (static code evidence)

Predecessor: Draft PR #64 fixes the global particle root drag. This second submission changes nine disjoint source files; PR #64's files remain untouched.

## Defects / proposed mitigations

T02 `VeilReleaseActivationView.swift`: page 0–3 uses parent `.gesture(swipeGesture)` while descendants contain vertical ScrollViews; switch to simultaneous observation and require horizontal dominance with 20pt minimum. Invisible entrance page is made non-hit-testable.

T03/T04 `ToolCenterView.swift`: PTT uses DragGesture(minimumDistance: 0) in ScrollView; hold gesture remains required, but onDisappear, recipient loss, and receive-state transitions force the pressed latch and transmitter off. Full scroll-vs-PTT gesture isolation remains a physical device check.

T05/T06 `MiniGameViews.swift`: both Gomoku and Xiangqi use transparent full-board zero-distance DragGestures for move selection. A drag release can register a false move. Xiangqi also attaches it when it is not the player's turn. Replace the two drag recognizers with one iOS15-compatible UIViewRepresentable *tap-only* UITapGestureRecognizer. It is non-cancelling, allows simultaneous parent recognition, and disables hit testing when the user cannot play. Preserve all legal position/turn checks.

T07 `PlatformerView.swift`: jumping requested continuously in onChanged; latch one jump per press and release on end, pause, background and disappearance.

T08 `TacticalLandscapeShellV2.swift`: map unit selection only occurs in .onChanged of DragGesture(minimumDistance:1), so a stationary tap may never select. Use minimumDistance 0 on map-only surface, and make decorative north marker non-hittable. Test map drags so taps do not accidentally issue routes.

T09 `SignalDiveLabView.swift`: stop thrust and reset control UI on scene becoming inactive or view disappearing, even if the gesture is cancelled without onEnded.

T10 `BlackoutDistrictLabView.swift`: same cancel protection for driving and repairing states.

T11 `AfterglowConvoyLabView.swift`: clear steering/shield when tutorial opens, backgrounding or leaving, not just scene pausing.

T12 `AshHarborLabView.swift`: zero throttle/rudder and release rescue state when inactive or navigating away, without resetting progression. Throttle selection on next appearance remains unchanged.

## Outside this patch: investigate without unsupported claims

- Stacked `ZStack` sheets/chrome hit zones and Islet expanded-navigation scrim must be tested; blocking touches while visibly expanded is intentional, lingering interception after dismissal would be a defect.
- Large-image viewer combines magnification, drag, single- and double-tap gestures; needs XCTest/UI traversal and physical tests before altering double-tap arbitration.
- Stress HUD is interactive and necessarily covers a top corner; measure obstruction and consider collapse/move only with user UX signoff.
- Theme switching, UIKit accessibility ids and first-responder recovery need iPhone7 dark/light regression. Current logs capture hit-tested view paths but do not prove an unmatched touch was blocked by that view.

No modifications to Keychain, SQLite, BLE protocol, signing, main product tree, or release workflows. This is an unbuilt proposal.
