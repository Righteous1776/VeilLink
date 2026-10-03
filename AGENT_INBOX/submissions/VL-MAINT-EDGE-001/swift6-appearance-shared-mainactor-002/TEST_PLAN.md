# Test Plan

## Static checks

1. Apply the advisory patch on an Integration Governor-controlled integration branch.
2. Confirm the product diff is exactly one line in `VeilLink/Core/AppearanceTheme.swift`.
3. Build with the repository's current strict-concurrency settings.
4. Search compiler output for:
   - `AppearanceTheme.swift`
   - `VeilAppearanceController.shared`
   - `main actor-isolated`
   - `concurrency-safe`
5. Acceptance requires the original singleton warning to disappear and no new call-site actor error to appear.

## Unit tests

Run the full existing `VeilLinkTests` inventory.

Specifically verify:
- `VeilAppearanceThemeTests.testThemeCatalogKeepsOriginalAppleSoftAndInstrumentAuto`
- `VeilAppearanceThemeTests.testInstrumentDayAndNightPalettesRemainDistinct`
- `GlobalAppearanceModeTests`
- `AppleSoftThemeTests`

No test-source modification is proposed.

## Integration tests

On iOS Simulator:

1. Launch VeilLink.
2. Switch appearance among Veil Original, Apple Soft, and Instrument.
3. Switch color mode among Auto, Light, and Dark.
4. Confirm root view and Settings update immediately.
5. Confirm navigation/tab chrome is reconfigured after appearance changes.
6. Relaunch and verify persisted selection/color mode are restored.
7. Exercise Tool Center and skeuomorphic components that read `VeilAppearanceController.shared`.

## Negative / failure cases

- Build all existing UI components to detect a synchronous non-main `shared` consumer.
- Exercise initial app bootstrap where `@StateObject private var appearance = VeilAppearanceController.shared` is initialized.
- Exercise `VeilChrome.configure()` during app init and appearance changes.
- If any legitimate background consumer exists after concurrent changes, do not bypass actor checking; move that consumer to MainActor or redesign the access path under Governor review.

## Regression invariants

- No theme palette values change.
- No UserDefaults keys change.
- `selection`, `colorMode`, and `systemIsDark` semantics remain unchanged.
- No transport/storage/security/protocol/A9/A10 behavior changes.
- Pure static palette values remain usable without MainActor isolation.

## Device / OS coverage

Minimum:
- repository CI Simulator/Xcode version;
- iOS 15 compatibility build.

Preferred smoke coverage:
- iPhone 7 / iOS 15.x;
- one current iPhone/iOS generation.
