# Proposal

## Goal

Remove the Swift 6 strict-concurrency diagnostic on `VeilAppearanceController.shared` without globally actor-isolating all static theme data.

## Current problem

Current main inherits the warning observed in successful iOS CI run `37108237656`:

`AppearanceTheme.swift:119:16: warning: static property 'shared' is not concurrency-safe because non-'Sendable' type 'VeilAppearanceController' may have shared mutable state; this is an error in the Swift 6 language mode`

The controller is an `ObservableObject` with mutable `@Published` appearance state and UIKit trait access. The singleton therefore represents UI-bound shared mutable state, but the declaration currently has no actor annotation.

## Proposed behavior

Annotate only the singleton property:

`@MainActor static let shared = VeilAppearanceController()`

Do **not** annotate the entire `VeilAppearanceController` type.

## Architecture / implementation

The singleton is the process-wide mutable UI state entry point. MainActor isolation expresses the intended access contract at the narrowest useful boundary.

Leaving the type itself unannotated is deliberate:

- static immutable palettes such as `instrumentDay` and `instrumentNight` remain synchronously accessible;
- existing palette-focused tests do not need actor annotations merely to inspect static values;
- actor isolation does not spread to unrelated pure theme constants;
- only code that accesses the mutable singleton must satisfy MainActor rules.

The proposal changes one declaration line and no runtime logic.

A Swift 6.2 strict-concurrency micro-compile was used to validate the language pattern: a non-Sendable reference type with `@MainActor static let shared` and separate nonisolated static constants compiles under `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`.

## User-visible impact

None expected. Theme selection, day/night behavior, persistence keys, palette values, and UIKit appearance behavior remain unchanged.

## Compatibility

The existing consumers identified during audit are UI-facing:
- `VeilLinkApp` uses `shared` as a `@StateObject`;
- `AdaptiveRootView` and `SettingsView` use it as an observed UI object;
- `VeilChrome.configure()` is already `@MainActor`;
- SwiftUI skeuomorphic components and Tool Center render theme state.

Integration must still compile the complete repository because SwiftUI protocol isolation annotations are SDK/toolchain-sensitive.

## Alternatives considered

1. **Mark the entire class `@MainActor`.** Rejected as unnecessarily broad; it would actor-isolate all static members, including immutable palette fixtures used by synchronous tests.
2. **Use `nonisolated(unsafe) static let shared`.** Rejected because it suppresses checking rather than encoding the intended UI-thread ownership of mutable state.
3. **Make the controller `@unchecked Sendable`.** Rejected because the object contains mutable published UI state and UIKit access; Sendable would be misleading.
4. **Replace singleton with dependency injection.** Potentially cleaner long-term, but far outside this maintenance task's risk budget.

## Acceptance criteria

- Proposed product diff touches only `VeilLink/Core/AppearanceTheme.swift`.
- Only `shared` receives `@MainActor`; the class itself remains unannotated.
- Existing appearance behavior is unchanged.
- Simulator build succeeds.
- Full XCTest succeeds.
- Build logs no longer contain the `VeilAppearanceController.shared` concurrency-safety warning.
- No new actor-isolation warning/error appears at any existing `VeilAppearanceController.shared` call site.
- `VeilAppearanceThemeTests.testInstrumentDayAndNightPalettesRemainDistinct` remains synchronously valid without test actor changes.
