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
- one successful model bake is cached and reused;
- night grading stays within 0...0.34 color blend.

## Rainline

- retain V2 deterministic replay and fault-kind coverage;
- 4 fault classes remain seed-stable;
- train model/alias failure returns to procedural shell;
- render profile affects only particles/noise/camera.

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
- memory/cache reset smoke via RealtimeGameAssetRuntime.clearCaches().
