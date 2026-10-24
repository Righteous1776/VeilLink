# Proposal

## Goal

Fix the real-device day/night switching defect where VeilLink changes text, system chrome and some outer surfaces immediately, while card/material backgrounds remain rendered with the previous theme for multiple seconds or until another unrelated redraw occurs.

The repair must be reactive, local to the visual layer, preserve navigation/business state, and work on iOS 15.

## Reproduction evidence

The owner supplied a 66.4-second iPhone screen recording of Settings while repeatedly switching display mode and appearance styles.

Frame-by-frame inspection shows a deterministic split-render symptom:

- the status/navigation/tab chrome changes between light and dark promptly;
- text and selection accents often follow the new mode;
- the large appearance card can remain on the previous mode;
- during the first ~17 seconds, the Instrument card repeatedly stays light while the surrounding chrome is dark;
- after the card finally repaints dark, the opposite split can be observed when the outer UI returns light first;
- the same class of mixed-frame behavior is visible while exercising Apple Soft.

This is not a palette-definition error: the day and night palettes are distinct and `VeilColorMode` resolves correctly. It is a SwiftUI dependency/invalidation error.

The video itself is not included in this Inbox package because ordinary Inbox submissions may not contain binary media.

## Root cause

Several central visual renderers read mutable theme state through:

`VeilAppearanceController.shared`

or through `VeilTheme`, which resolves through that singleton, but the renderers themselves do **not** declare a SwiftUI dynamic dependency on the controller.

The key affected layers are:

- `VeilAmbientBackground`;
- `VeilCardModifier`;
- `VeilInstrumentBackground`;
- `VeilInstrumentPlate`;
- `VeilDynamicGlowBorder`.

`SettingsView` itself already has:

`@ObservedObject private var appearance = VeilAppearanceController.shared`

so its directly-rendered labels and controls invalidate immediately. The nested material renderers can remain cached because their own inputs have not changed from SwiftUI's perspective. That explains the recording: foreground/text and system chrome move to the new mode while the card material stays on the old palette.

This is also why changing palette constants would not fix the defect.

## Proposed behavior

Make each central theme-sensitive material renderer explicitly observe the shared appearance controller.

For the renderers that branch on appearance flags or derive the active palette, replace raw singleton lookups with the observed property.

No forced view identity reset is used.

No delayed workaround is used.

No timer is used.

No navigation/root reconstruction is used.

## Architecture / implementation

### 1. Core ambient background

`VeilAmbientBackground` gains:

`@ObservedObject private var appearance = VeilAppearanceController.shared`

Its style selection and dark/light branch use `appearance` directly.

This guarantees the app/background material participates in the same publication cycle as the settings controls.

### 2. Core card modifier

`VeilCardModifier` gains the same observed dependency.

Its Plainline / Islet / Apple Soft / Instrument branch selection uses `appearance` rather than untracked singleton reads.

This is the most important fix for the supplied recording because every Settings card is built through `.veilCard(...)`.

### 3. Instrument material primitives

`VeilInstrumentBackground` and `VeilInstrumentPlate` each observe the controller.

Their palette and dark/light contrast decisions use the observed instance.

This prevents an Instrument card or background from remaining on an old metal/recess palette after the text already switched.

### 4. Dynamic glow

`VeilDynamicGlowBorder` observes the controller and uses the observed instance for Instrument shape selection.

The existing rotating state remains intact; a theme change repaints the glow but does not reset navigation or business state.

### 5. Regression tests

`GlobalAppearanceModeTests` gains:

- a MainActor test proving forced Light -> Dark immediately changes the Instrument palette without waiting for UIKit trait synchronization;
- a source-level architecture invariant ensuring the key renderers continue to own `@ObservedObject` appearance dependencies.

The source invariant is intentional: the bug is not incorrect palette math, but loss of SwiftUI dependency registration. A palette-only unit test cannot detect that regression.

## Why not rebuild the whole UI with .id(...)

A root `.id(appearance.colorMode)` would force the visual result to update, but it would also recreate view identity and can reset:

- navigation state;
- local sheet state;
- scroll position;
- transient input state;
- child `@State` values.

That is an unacceptable workaround for a theme refresh defect.

The proposed fix invalidates only the material renderers that actually depend on the appearance controller.

## Why not add a timer/delay

The recording already shows the old material eventually repainting after unrelated invalidation. Waiting longer is not correctness.

A theme switch must make every theme-sensitive layer reactive to the same state source.

## User-visible impact

Expected behavior after integration:

- switching Light -> Dark updates card, background, text, edge/glow and chrome as one coherent transition;
- switching Dark -> Light does the reverse;
- Auto follows system changes without stale card material;
- theme selection still works;
- no navigation reset;
- no scroll reset;
- no artificial delay;
- no new animation is introduced.

## Compatibility

- iOS 15+: `ObservedObject` is already used throughout VeilLink.
- iPhone 7: no new compositor feature or material API is introduced.
- current iOS: behavior remains native.
- persistence: unchanged.
- theme palette values: unchanged.
- UserDefaults keys: unchanged.
- app/release identity: unchanged.

## Acceptance criteria

1. The supplied Settings reproduction can be repeated with at least 20 rapid Light/Dark switches without a mixed old/new palette persisting beyond the current render pass.
2. Instrument card fill, surrounding ambient background, text and dynamic edge agree on the same mode after each switch.
3. Apple Soft cards do not remain on the prior mode after the surrounding chrome changes.
4. Auto mode follows a system appearance change coherently.
5. No navigation, sheet, scroll or text-input state resets during a mode switch.
6. Existing selectable themes remain unchanged.
7. Full simulator build and XCTest pass.
8. iPhone 7 / iOS 15 physical smoke test passes.
9. No product behavior outside the visual/theme layer changes.
