# Asset Pipeline V3

## Canonical order

`optimized 2D alias -> staged source asset -> procedural fallback`

## Runtime model bridge

The proposed shared runtime can render a bundled OBJ into a cached SpriteKit texture using SceneKit when the optimized alias is missing.

This exists to remove manual blocking during integration, not to make SceneKit the permanent renderer.

## Preferred integration

For release-quality integration the Governor may:

1. preserve the staged OBJ/MTL pair;
2. render the model with the V3 camera/orientation recipe;
3. export a transparent 2D image/atlas;
4. register the expected alias from REALTIME_GAME_ASSET_CATALOG.json;
5. keep the OBJ path as development fallback or remove it after visual verification.

## Stable aliases

Rainline:
- rainline_kenney_train_car
- rainline_kenney_track_detailed

Signal Dive:
- signal_dive_kenney_fish_1
- signal_dive_kenney_fish_2
- signal_dive_kenney_fish_3

Blackout:
- blackout_kenney_service_truck
- blackout_kenney_commercial
- blackout_kenney_road_straight

## LOD policy

- motionReduced: fewer particles/noise and no gameplay changes;
- standard: phone baseline;
- cinematic: larger canvas / iPad detail multiplier.

LOD never changes deterministic rules, collision, faults, sonar contacts, grid connectivity or outcome.

## Night grading

Third-party sprites receive a scene-specific color blend after load:
- Rainline: cold blue commuter-night grade;
- Signal Dive: deep cyan underwater grade;
- Blackout: blue-cyan storm/utility grade.

This keeps mixed Kenney packs from appearing as visually unrelated raw assets.
