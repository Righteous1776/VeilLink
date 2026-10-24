# Test Plan

## Static checks

1. Apply the advisory patch on a Governor-controlled integration branch based on `8048b5c52b87eeb5d3622582da5728a8c2d64dda` or a reviewed descendant.
2. Run `git diff --check`.
3. Confirm only these proposed product/test files are touched:
   - `VeilLink/Core/AppTheme.swift`
   - `VeilLink/Core/SkeuomorphicComponents.swift`
   - `VeilLink/Core/VeilMotionKit.swift`
   - `VeilLinkTests/GlobalAppearanceModeTests.swift`
4. Confirm no `.id(appearance...)`, timer, delay, DispatchQueue workaround or root navigation reconstruction was introduced.
5. Confirm the five key rendering types own a live `@ObservedObject` dependency:
   - `VeilAmbientBackground`
   - `VeilCardModifier`
   - `VeilInstrumentBackground`
   - `VeilInstrumentPlate`
   - `VeilDynamicGlowBorder`

## Unit tests

Run the full existing XCTest inventory.

New/expanded focused tests:
- `GlobalAppearanceModeTests.testForcedInstrumentModeChangesPaletteImmediately`
- `GlobalAppearanceModeTests.testCoreThemeSurfaceRenderersObserveAppearanceChanges`

Existing focused tests:
- `GlobalAppearanceModeTests.testLightAndDarkResolutionAreDeterministic`
- `GlobalAppearanceModeTests.testAutomaticFollowsSystem`
- `VeilAppearanceThemeTests.testInstrumentDayAndNightPalettesRemainDistinct`
- `VeilAppearanceThemeTests.testThemeCatalogKeepsExistingChoicesAndGatesExperimentalStyles`
- `AppleSoftThemeTests`

## Integration reproduction — mandatory

Use the supplied recording as the behavioral reference, but do not add it to Git history.

On Settings -> 外观主题:

### Instrument
1. Select `拟物仪器`.
2. Toggle Light -> Dark -> Light at least 20 times.
3. Include several rapid alternations under one second apart.
4. After every tap verify in the same render pass:
   - card metal fill;
   - card border;
   - card text;
   - ambient/background;
   - dynamic orange glow;
   - navigation/tab chrome;
   all agree on the selected mode.
5. No old light card may remain visible inside a dark shell.
6. No old dark card may remain visible inside a light shell.

### Apple Soft
Repeat the same Light/Dark alternation and verify the soft surface, text and system chrome do not split across modes.

### Veil Original / Islet
Repeat a shorter 5-switch matrix and confirm card/background/text stay coherent.

### Auto
1. Select Auto.
2. Change simulator/device system appearance Light -> Dark -> Light.
3. Verify the same surfaces update together.

## State-preservation checks

While switching modes:
- remain on the Settings screen;
- keep the same scroll position;
- keep any expanded local UI state intact;
- do not reset navigation selection;
- do not dismiss unrelated sheets;
- do not recreate AppModel or session state.

This specifically guards against a future root `.id(...)` workaround.

## Timing / visual acceptance

The defect in the supplied recording persists across multiple seconds and unrelated redraws. After the patch:

- no stale material may survive into a later frame once the selected mode has been committed;
- no multi-second lag is acceptable;
- no visibly mixed foreground/background palette is acceptable.

For automated screenshot evidence, capture the Settings appearance card after each settled mode and compare representative card/background luminance direction:
- Light must be the light palette;
- Dark must be the dark palette.

Do not require pixel-identical snapshots across OS versions.

## Performance

Use Instruments or basic signposts during 20 rapid toggles:
- no runaway body-update loop;
- no sustained CPU spike after switching stops;
- dynamic glow retains its existing motion state;
- no additional persistent timer or display link is introduced.

The controller only publishes appearance state changes, so extra invalidation is bounded to actual appearance changes.

## Device / OS coverage

Mandatory:
- current repository iOS Simulator/Xcode;
- iPhone 7 / iOS 15.x physical smoke test because the supplied UI architecture has legacy-compositor paths;
- one current iPhone/iOS generation.

## Full regression

Run:
- static preflight;
- XcodeGen;
- iOS Simulator build;
- complete XCTest;
- existing render compatibility and device performance tests.

No release, IPA, signing or publication workflow is part of this Lane Agent task.
