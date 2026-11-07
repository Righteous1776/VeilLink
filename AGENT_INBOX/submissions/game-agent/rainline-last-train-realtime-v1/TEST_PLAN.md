# Test Plan

## Static checks

- Apply PATCH.diff against exact base_main_sha.
- Confirm only four declared product/test files are proposed.
- Strict-concurrency scan.
- Confirm SpriteKit/CoreImage/UIKit imports resolve on iOS target.
- Standard repository preflight after Governor application.

## Unit tests

1. Identical seed + identical input stream yields equal state.
2. trainPower remains within 0...100.
3. traction remains within 0...100.
4. all eight carPower values remain within 0...1.
5. deterministic fault generation is stable for equal seed.
6. player position remains inside train bounds.
7. repair requires correct carriage + repair input + low enough movement.
8. repaired fault stops contributing active-fault load.
9. finished state becomes immutable.
10. route progress is monotonic while running.

## Scene / integration tests

- SpriteView presents without crash.
- rebuilding size does not duplicate the train hierarchy.
- eight carriage nodes render with independent brightness.
- player sprite crosses car boundaries smoothly.
- active faults add/remove spark emitters without leaking nodes.
- CIBloom filter applies to train lighting.
- glass rain shader compiles.
- low train power changes glass tint toward emergency red.
- city parallax continues while train traction is nonzero.
- lightning overlay remains finite and does not accumulate actions indefinitely.
- restart clears fault emitters and state.

## Rendering checks

- visible eight-car cutaway;
- warm/cold per-car light transition;
- passenger silhouettes readable in lit cars;
- bloom around interior lights;
- neon city depth from two skyline layers;
- reflection streaks below skyline;
- external rain + glass-rain streaks simultaneously visible;
- electrical spark emitters on faulted cars;
- lightning exposure flash;
- no old-device particle-density reduction required for this task.

## Negative / failure cases

- player holds movement against train end;
- repair attempted in wrong car;
- repair attempted while moving too quickly;
- multiple simultaneous faults;
- boost grid held until near-blackout;
- trainPower reaches zero;
- traction reaches zero;
- restart after each terminal outcome.

## Regression invariants

- MiniGameKind unchanged.
- Existing ArcadeGames/ArcadeGameViews unchanged.
- No wire/protocol/schema/persistence change.
- No workflow/version/build/release/signing change.
- No A9/A10 governance mutation.

## Device / OS coverage

- iOS semantic compile under current project target.
- current-generation iPhone visual target.
- iPad aspect-ratio smoke.
- 60 fps target on modern hardware.
- iPhone 7 performance is explicitly not a gating requirement for this proposal.
