# Test Plan

- deterministic replay with equal seed/input;
- resource bounds for train power, traction and eight car-power values;
- fault generation remains seed-stable;
- fault-kind sequence remains seed-stable;
- representative seed corpus produces at least three fault kinds;
- lighting/traction/thermal/comms paths preserve bounds;
- terminal states remain immutable;
- story beats advance with route progress;
- Reduce Motion lowers transient visual intensity without changing state;
- missing rainline_kenney_train_car image uses procedural train shell;
- missing ShaderKit noise resource returns nil and does not crash;
- staged GLB byte count/SHA-256 match ASSET_MANIFEST.json;
- iOS 15 semantic compile, full XCTest and iPad layout smoke during Governor integration.
