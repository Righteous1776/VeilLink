# Proposal — Realtime Game Render Runtime V3

## Why this exists

Rainline, Signal Dive and Blackout District reached V2 with separate asset loaders, Reduce Motion logic and fallback paths. V3 collapses those parallel solutions into one auditable runtime.

## Resolution order

Every supported third-party visual follows:

1. final optimized 2D alias;
2. staged third-party model/vector source;
3. deterministic procedural fallback.

The game never requires a network fetch.

## Shared runtime

`RealtimeGameAssetRuntime` provides:

- stable asset IDs and aliases;
- per-scene image/texture cache with no global mutable runtime state;
- recursive bundle resource discovery;
- safe shader loading;
- viewless SCNRenderer OBJ snapshot fallback into SpriteKit textures;
- per-game night grading;
- shared standard / cinematic / Reduce Motion render profiles, including particle, Bloom, noise and camera scaling.

OBJ snapshotting is a compatibility bridge. Governor integration should prefer an optimized 2D atlas when one exists.

## Rainline

- carries V2 four fault classes and richer route story;
- train shell now resolves through the shared pipeline;
- one SCNRenderer model snapshot is cached inside the Rainline scene and reused across the train;
- ShaderKit storm noise uses the shared safe loader;
- particle/noise/camera policy uses the shared render profile.

## Signal Dive

- carries deterministic biological sonar contacts;
- PNG fish aliases use the shared image resolver;
- Kenney Fish Pack vector fish remain the direct CC0 fallback;
- procedural fish remains the final safety fallback;
- particulate density/camera policy uses the shared profile.

## Blackout District

- carries the 12-node / >130-building V2 network;
- service truck resolves PNG -> Kenney OBJ -> procedural truck;
- commercial buildings resolve PNG -> Kenney OBJ -> procedural building;
- building window overlays remain independently controllable after third-party art loads;
- road OBJ is retained as a source for future offline tile baking; graph road geometry remains authoritative;
- ShaderKit noise/radial shader lookup, rain and camera policy use the shared runtime.

## Compatibility

- source remains compatible with the existing iOS 15 target expectations;
- Reduce Motion is presentation-only;
- iPad/large canvases select cinematic detail rather than separate game rules;
- missing images/models/shaders never invalidate simulation state;
- no networking, protocol, schema, identity, A9/A10, release or workflow changes.
