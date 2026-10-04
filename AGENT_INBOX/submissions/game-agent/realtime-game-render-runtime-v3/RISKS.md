# Risks

## Intentional overlap

This V3 submission intentionally overlaps and supersedes:
- PR #32 Rainline V2;
- PR #33 Signal Dive V2;
- PR #34 Blackout District V2.

Governor should not combine those three V2 product patches with V3 file-by-file. V3 already carries their final game logic forward.

## SceneKit bridge

SceneKit SCNRenderer snapshot APIs are deprecated in the current SDK. V3 uses the viewless renderer only as a temporary local fallback when an optimized 2D alias is absent.

Mitigation:
- final alias remains highest priority;
- fallback result is cached;
- pipeline documents offline bake as preferred release path;
- procedural rendering remains the last fallback.

## First-use latency

Loading an OBJ and taking the first snapshot may cause a one-time hitch.

Mitigation:
- one snapshot per asset/size cache key inside the owning scene;
- repeated Rainline cars reuse one texture;
- Governor may pre-bake aliases before release.

## Resource pairing

OBJ files reference companion MTL names. Asset integration must preserve relative pairing or rewrite the reference.

## Visual consistency

Raw Kenney packs use brighter palettes than VeilLink night scenes.

Mitigation:
- common night-grade layer;
- final atlas may be color-graded offline.

## Signal vector parser

SignalDiveKenneyVectorArt intentionally supports only the bounded SVG command subset used by selected Fish Pack fragments.

## Runtime deprecation horizon

A future SDK may remove SceneKit. Because SceneKit is not the authoritative path, removal requires replacing only the model bridge; aliases, staged sources and procedural fallback remain intact.

## Protected surfaces

No transport, storage, wire protocol, schema, identity, key management, A9/A10 governance, workflow, version/build, signing or release surface is changed.
