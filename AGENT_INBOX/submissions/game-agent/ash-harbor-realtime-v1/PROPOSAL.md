# Proposal

## Goal

Create **Ash Harbor / 灰港**, a real-time 2D storm-rescue game that advances the VeilLink game line beyond turn-based mini-games and simple Canvas scenes.

The game should feel lonely, tense and humane without relying on long cutscenes or large binary assets.

## Core fantasy

A storm has blacked out an old harbor district. The player pilots a small rescue craft along the lighthouse route before a wind wall closes the harbor.

Four distress signals remain. Each rescue requires slowing down, holding position in rough water and spending precious time while debris and storm pressure continue.

The emotional question is not “how high is the score?” but “how many lights can I bring back before the route closes?”

## Gameplay

### Real-time deterministic core

- fixed simulation step: 60 Hz;
- continuous throttle;
- vertical rudder/steering;
- deterministic storm push;
- hull integrity and searchlight battery;
- debris collisions;
- hold-to-rescue zones;
- four authored distress sites;
- 150-second route deadline;
- destination / hull-loss / time-expired outcomes.

The gameplay state is independent from SpriteKit rendering, making deterministic tests and future replay/network design possible.

### Rescue tension

Rescue requires:

- proximity to the distress site;
- low enough boat speed;
- sustained rescue input for the site's hold duration.

If the player rushes, the rescue cannot complete. Slowing down costs time and leaves the boat exposed to storm/debris movement.

### Searchlight

The searchlight consumes battery while active and recharges slowly while off. In the renderer it exposes nearby hazards and rescue markers more clearly. V1 does not make hidden collision state dependent on rendering; the mechanic stays deterministic and accessible.

## Rendering

`AshHarborScene` uses SpriteKit as a persistent real-time renderer:

- layered harbor silhouettes;
- warm building-window pin lights;
- procedural rain emitter;
- moving fog bands;
- programmatic rescue flares;
- debris sprites built from code geometry;
- searchlight cone;
- water surface using an original fragment shader;
- storm color overlay;
- impact spray;
- camera shake;
- adaptive full/constrained render tiers.

### Water shader

The proposed shader is original and compact. It uses two sine wave bands, a crest mask and storm/progress uniforms to create a moving cold-water surface that warms slightly near the route end.

ShaderKit is treated as an architectural/effect reference only in this drop. No ShaderKit source is copied.

## Open-source / public-domain integration strategy

See `OPEN_SOURCE_INTAKE.md` for exact license and adoption posture.

The short version:

- **ShaderKit (MIT):** candidate effect library / reference; no source vendored in V1.
- **LDtk (MIT):** recommended offline level editor; no runtime dependency required.
- **Ink/Inky (MIT):** recommended offline narrative authoring reference; no sample story text copied.
- **Kenney Watercraft Kit (CC0):** recommended boat/model source for offline 2D sprite rendering.
- **Poly Haven (CC0):** recommended texture/HDRI source for offline baking into small atlases.

The game remains buildable without any of them in this first proposal.

## Story / emotion design

Radio lines are short and tied to action state, not cutscenes.

Each rescue site has one original line. The ending changes tone based on how many signals were recovered. The radio should feel like a fragile human thread through the storm, not a mission-announcer UI.

See `STORY_BEATS.md`.

## Why not import a full engine

Godot and AdaEngine are strong standalone engines, but importing a second full engine into VeilLink would increase integration surface and undermine the current SwiftUI/SpriteKit architecture.

OctopusKit is architecturally interesting, but its repository explicitly says it is no longer updated by its sole maintainer.

Therefore this proposal keeps Apple-native rendering and cherry-picks techniques/tools instead of replacing the host architecture.

## Compatibility

- iOS 15 target preserved;
- no new package dependency;
- no project.yml edit;
- no network/wire/replay/database changes;
- no model weights or runtime downloads;
- no asset binaries committed by this Inbox proposal;
- no version/release/workflow changes.

## Acceptance criteria

- identical seed + input stream produces identical state;
- rescue requires low speed + hold duration;
- hull/battery remain bounded;
- finished state is immutable;
- real-time renderer shows layered harbor, rain, fog, searchlight, water shader and impact feedback;
- constrained render tier materially reduces particle/node load;
- third-party adoption is auditable before any asset/code is imported;
- full iOS Simulator build + XCTest + real-device iPhone 7 profiling before permanent navigation wiring.
