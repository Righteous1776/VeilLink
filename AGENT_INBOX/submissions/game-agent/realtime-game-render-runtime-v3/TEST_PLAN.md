# Test Plan

## Shared runtime

- standard profile resolves on 390x844;
- cinematic profile resolves on large canvas;
- Reduce Motion overrides canvas size;
- all image aliases are unique;
- all model resource names are unique;
- missing alias/model returns nil rather than crashing;
- missing shader returns nil rather than crashing;
- recursive resource lookup finds nested staged resources after Governor import;
- one successful model bake is cached and reused inside the owning game scene;
- night grading stays within 0...0.34 color blend.

## Rainline

- retain V2 deterministic replay and fault-kind coverage;
- 4 fault classes remain seed-stable;
- train model/alias failure returns to procedural shell;
- render profile affects only presentation: particles/noise/Bloom/camera.

## Signal Dive

- retain biological sonar determinism and vector-art construction tests;
- PNG alias -> vector -> procedural order smoke test;
- Reduce Motion remains presentation-only.

## Blackout District

- retain 12-node, >130-building, 4-critical-node tests;
- service-truck and commercial-building source failures fall back procedurally;
- third-party building still receives controllable window overlay;
- road simulation remains graph/path driven;
- missing ShaderKit resources remain safe.

## Integration gates

- Agent Inbox Gate;
- exact SHA-256 / byte validation for all 10 staged assets;
- iOS 15 semantic build;
- current SDK build with SceneKit deprecation treated as warning only;
- simulator launch;
- full XCTest;
- real-device first-load model snapshot smoke;
- memory/cache reset smoke via a scene-owned RealtimeGameAssetRuntime instance.


## Mobile touch-control audit

- Rainline: press-and-hold forward/backward, repair, and grid boost; verify release returns the corresponding input to neutral and two controls can be held on separate fingers.
- Signal Dive: drag the gameplay surface in all four directions; verify screen drag direction matches submarine movement, release zeros thrust, and sonar/floodlight buttons remain independently tappable.
- Blackout District: drag up/down for forward/reverse throttle and left/right for matching vehicle steering; verify release zeros throttle/steering and repair can be held independently while the drive pad is idle or lightly engaged.
- Navigate away / present result overlay after active input and confirm restart begins from neutral input state.
