# Test Plan

## Core tests

1. Equal seed + equal 4,000-step input stream produces equal state.
2. Grid stability remains 0...1.
3. Powered-node count remains 0...total nodes.
4. Lit-building count remains 0...total buildings.
5. Storm eventually creates at least one fault for representative seeds.
6. Different seeds diverge under storm stress.
7. Terminal state is immutable.
8. Initial city declares 9 nodes and >90 building units.
9. Repair path is validated with an integration harness that positions the truck near a fault and confirms low-speed hold is required.
10. Critical-node failure changes connectivity and radio state.

## Rendering / integration

- SpriteView presents without crash.
- scene restart is idempotent and does not reparent existing nodes.
- dynamic noise shader resource resolves from bundle.
- radial gradient shader resource resolves from bundle.
- ShaderKitExtensions compiles under the current target.
- Core Image Bloom resolves.
- city window groups update from actual node power.
- grid lines change color/glow when connectivity changes.
- Kenney sprite aliases render when resource images are present.
- missing optional Kenney images cleanly fall back to procedural geometry.
- rain, puddles, lightning and repair/fault bursts remain bounded.
- camera follows vehicle across map.

## Third-party compliance

- preserve ShaderKit MIT notice.
- verify exact ShaderKit revision used.
- reverify Kenney CC0 status immediately before binary asset import.
- store source URLs and derivative filenames.
- do not import entire 3D/2D packs when only a subset is needed.
- do not add binary packs to Agent Inbox.

## Regression invariants

- existing game files unchanged.
- MiniGameKind unchanged.
- protocol/schema/storage unchanged.
- workflows/version/release/signing unchanged.
- A9/A10 governance unchanged.

## Device policy

- iOS 15 compile compatibility required.
- modern iPhone/iPad rendering prioritized.
- iPhone 7 performance explicitly not a design gate for this game.
