# VeilLink 26.12 · Build 58

Build 58 is the real-time rendering and game-content release following VeilLink 26.11 Build 57.

## Highlights

- Adds Prism Rift 3D, a SceneKit tunnel-action game with dynamic lighting, HDR/bloom, streamed encounters and three moving boss battles.
- Adds Afterglow Convoy, a deterministic SpriteKit escort game with layered ruins, rain, fog, beacon effects, shields and authored story beats.
- Adds Ash Harbor, a storm-rescue game with continuous boat control, four rescue sites, searchlight/battery management and an original water shader.
- Adds Rainline Last Train, Signal Dive and Blackout District from the governed Agent Inbox V3 batch, including richer fault, sonar, repair and infrastructure systems.
- Adds a shared local asset/render runtime with per-scene caches, Reduce Motion support, standard/cinematic profiles and procedural fallbacks.
- Imports ten audited Kenney CC0 OBJ/MTL resources and retains ShaderKit's MIT license plus Kenney provenance records.
- Expands deterministic gameplay, render-policy, missing-resource and asset-runtime XCTest coverage.

## Rendering and performance

- Real-time games use persistent SpriteKit or SceneKit frame loops rather than static or one-frame presentations.
- Rendering adapts particle density, bloom, noise, antialiasing and detail to device capability and accessibility settings.
- Authenticated God Mode retains the ability to force full effects and the existing high-refresh policy.
- Gameplay simulation stays fixed-step and independent from presentation quality, so reducing effects does not change rules or outcomes.

## Compatibility and safety

- Minimum deployment target remains iOS 15 for the main app.
- Protocol 4, VLGM1 v1, SQLite Schema V8, identity/key contracts, BLE/LAN transport contracts and signing material are unchanged.
- All new games and assets are offline; no runtime asset download or telemetry is introduced.
- The published Core IPA is unsigned and requires appropriate Apple signing/provisioning before normal-device installation.
- Simulator and XCTest results do not replace physical-device frame pacing, thermal, battery, BLE/LAN radio or background testing.

## Validation gates

Publication is blocked unless static preflight, asset provenance checks, XcodeGen generation, iOS Simulator build, the full XCTest inventory, unsigned iPhoneOS Release build, Core source-isolation and size/resource verification, release manifest generation, provenance generation and SHA-256 checks all succeed.
