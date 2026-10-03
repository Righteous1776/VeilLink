# Test Plan

## Static checks

1. Apply the advisory patch to an Integration Governor-controlled integration branch based on the recorded `base_main_sha` or a reviewed descendant.
2. Confirm the diff touches only `VeilLink/Diagnostics/DeepTelemetry.swift`.
3. Confirm all eight affected `NotificationCenter.addObserver` registrations still contain `queue: .main`.
4. Build with the repository's current strict-concurrency warning settings.
5. Search compiler output for:
   - `DeepTelemetry.swift`
   - `sending 'notification' risks causing data races`
   - `capture of`
   - `main actor`
6. Acceptance requires the eight targeted diagnostics to be absent with no replacement warning introduced at the modified lines.

## Unit tests

Run the complete existing `VeilLinkTests` inventory. No test source changes are proposed.

Pay particular attention to:
- `DiagnosticLogStoreTests`
- existing privacy/invariant tests
- any test that initializes `DeepTelemetry.shared` or diagnostic infrastructure indirectly

## Integration tests

On an iOS Simulator:

1. Launch VeilLink and allow DeepTelemetry to install normally.
2. Focus and edit a standard `UITextField`; verify begin/change/end lifecycle telemetry remains present.
3. Focus and edit a `UITextView`; verify begin/change/end lifecycle telemetry remains present.
4. Show and hide the software keyboard; verify `input.keyboard` telemetry still records state and, when provided by UIKit, frame/animation metadata.
5. Confirm no crash, main-thread assertion, or actor precondition occurs during repeated focus changes.

## Negative / failure cases

- Rapidly alternate focus between text field and text view.
- Dismiss the keyboard interactively while editing.
- Trigger text changes while the app is transitioning between active/inactive state.
- Confirm observers are not duplicated and no event schema changes.
- If any affected observer is ever changed away from `queue: .main`, reject this patch or redesign the boundary; the local unsafe assertion must not survive such a queue change unreviewed.

## Regression invariants

- Event names remain unchanged.
- `recordTextField`, `recordTextView`, and `recordKeyboard` remain main-actor isolated through `DeepTelemetry`.
- Privacy gating in `shouldCaptureTextField` remains unchanged.
- No plaintext input content is added to telemetry.
- Existing asynchronous task hop is preserved.
- No transport, storage schema, identity, protocol, A9/A10 governance, release, signing, or build-version behavior changes.

## Device / OS coverage

Minimum validation:
- iOS Simulator using the repository's CI Xcode version.
- iOS 15 compatibility build because VeilLink still targets legacy devices such as iPhone 7.
- Current iOS simulator runtime used by CI.

Preferred physical smoke test during a later integration window:
- iPhone 7 / iOS 15.x
- one current iPhone/iOS generation
