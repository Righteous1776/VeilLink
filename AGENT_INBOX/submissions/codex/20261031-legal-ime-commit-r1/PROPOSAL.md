# Reproduced Build64 race

The signing action currently calls `resignFirstResponder` and evaluates `canSign` immediately in the same call stack. With a marked Chinese IME composition, UIKit commits the final text through field/delegate callbacks, while SwiftUI's `@State` propagation can occur after the immediate check. The first tap can therefore show “请准确输入” even though the visible field contains the exact phrase.

This is the same mandatory gate where inability to sign blocks the entire application, so a residual one-tap race is P0 even if it is device/keyboard dependent.

# Proposed repair

1. Add a `signing` state guard so a rapid double tap cannot create two acceptance records.
2. On tap, resign the first responder and defer the actual validation one main-loop turn.
3. In `textFieldDidEndEditing`, synchronously publish the final UIKit text after IME marked text is committed.
4. Validate and persist using the unchanged `VeilLegalConsentRequirements` and `VeilLegalConsentController.accept` paths.
5. Re-enable the button after incomplete input or secure-storage failure; successful acceptance continues into the app as before.

No agreement wording, hash, required phrase or evidence format changes.
