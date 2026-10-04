# Test Plan

## Static checks

- Apply PATCH.diff against exact base_main_sha.
- Confirm only four declared new product/test files are introduced.
- Swift strict-concurrency scan.
- Confirm SpriteKit/UIKit imports on iOS 15.
- Confirm no new Swift Package/project dependency.
- Standard repository preflight after Governor application.

## Unit tests

1. Equal seed + equal 2,500-step input stream yields exactly equal state.
2. Hull and battery remain within 0...100 during long simulation.
3. Rescue requires proximity, low speed and sustained hold input.
4. Finished state does not advance.
5. Searchlight consumes more battery than an equivalent dark run.
6. Debris collision is resolved once per debris ID.
7. Time limit resolves `timeExpired`.
8. Reaching world end resolves `reachedHarbor`.

## Scene / integration tests

- SpriteView presents without crash.
- `didChangeSize` safely rebuilds backdrop/water/weather.
- Water shader compiles on iOS 15 simulator/device.
- Searchlight toggles and tracks battery state.
- Rescue ring appears only for active rescue.
- Nearby debris/rescue node streaming remains bounded.
- Restart removes stale nodes and state.
- HUD callbacks remain main-actor safe.
- Bounded accumulator prevents spiral-of-death after a frame hitch.

## Rendering checks

Full tier:
- layered parallax harbor;
- dense rain;
- moving fog;
- water shader;
- searchlight cone;
- rescue flares;
- spray and camera shake;
- storm overlay.

Constrained tier:
- reduced rain birth rate;
- fewer fog bands;
- lower spray count;
- reduced camera shake;
- same gameplay state/output as full tier.

## Open-source intake checks

Before any third-party asset/code enters product tree:

- pin source URL and exact version/commit where possible;
- verify license at source;
- store required MIT/Apache notices;
- confirm CC0 asset provenance;
- do not import sample assets with mixed licenses;
- do not import third-party story text;
- rasterize/bake only selected Kenney/Poly Haven material needed by the game;
- measure final binary-size impact.

## Negative / failure cases

- maximum throttle in severe storm;
- sustained wall collision;
- battery reaches zero while searchlight requested;
- rescue input while moving too fast;
- rescue input outside range;
- route deadline reached mid-rescue;
- hull reaches zero;
- repeated restart;
- Reduce Motion;
- Low Power Mode / constrained tier.

## Regression invariants

- MiniGameKind unchanged.
- Existing game code/views unchanged.
- No wire/protocol/schema/persistence changes.
- No workflow/version/build/release/signing changes.
- No A9/A10 governance mutation.

## Device / OS coverage

- iOS 15 minimum.
- iPhone 7-class constrained tier.
- current iPhone portrait.
- iPad layout smoke.
- Reduce Motion.
- Low Power Mode.
- VoiceOver/Dynamic Type on SwiftUI HUD.
- 60 fps target full tier on modern devices; constrained tier prioritizes stable frame pacing.
