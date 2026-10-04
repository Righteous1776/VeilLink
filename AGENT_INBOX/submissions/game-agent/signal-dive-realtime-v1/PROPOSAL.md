# Proposal

## Goal

Create **Signal Dive / 深潜信号**, a real-time 2D deep-sea exploration/search title where **sonar is a core perception mechanic rather than a decorative effect**.

The game should feel quieter and larger than the previous titles. The emotional arc comes from descending into spaces where the floodlight reveals very little, recovering four lost signals, then bringing them back toward the surface.

## Core fantasy

Four autonomous survey beacons stopped transmitting along a trench.

The player pilots a small submersible into increasingly deep water. Floodlight range is local and limited. Sonar reveals terrain, missing beacons and very large distant echoes for a few moments.

Each sonar pulse costs power and increases acoustic disturbance. The deeper the sub goes, the greater the pressure and the darker the environment becomes.

The objective is not simply to reach the bottom. It is to recover all four signals and return to shallow water near the far-side recovery route.

## Gameplay

### Deterministic 60 Hz core

- two-axis continuous thrust;
- drag/damping and bounded world/depth;
- hull integrity;
- battery power;
- depth-derived pressure;
- acoustic noise/disturbance;
- floodlight power drain;
- sonar pulse power cost + cooldown;
- deterministic obstacles;
- four authored beacon locations;
- low-speed beacon recovery;
- deterministic distant “massive unknown” echo field;
- terminal states: surfaced, hull failure, power loss.

### Sonar

A sonar pulse:

- costs power;
- raises noise;
- starts a 1.5 s cooldown;
- returns a sorted deterministic contact list;
- identifies terrain vs beacon vs massive unknown class;
- drives the visual sonar ring and temporary screen-space echo blips.

The renderer does not invent gameplay contacts. It visualizes the same contact list produced by the deterministic core.

### Pressure

Pressure rises with depth. It:

- reduces thrust effectiveness modestly;
- increases visual fog/darkening;
- increases collision consequences near the depth limit.

Pressure is not a random failure roll.

## Rendering architecture

`SignalDiveScene` uses SpriteKit + Core Image:

- programmatic submersible silhouette;
- Core Image bloom around floodlight;
- floodlight cone;
- suspended particulate emitter;
- layered abyss silhouettes;
- terrain rocks;
- pulsing beacons;
- full-screen abyss-fog fragment shader;
- pressure darkening overlay;
- sonar expansion ring;
- temporary echo blips;
- very large distant unknown silhouettes;
- impact particle bursts;
- camera shake;
- cyan recovery/sonar flashes.

The scene is intentionally more visually ambitious than the early lightweight Game Lab titles.

## Emotional pacing

The deeper the player goes:

- background color loses saturation;
- radio lines become shorter;
- floodlight covers a smaller-feeling portion of the scene;
- unknown silhouettes become more readable only through sonar;
- retrieved beacon lines act as sparse confirmation that something human-made is still down there.

The ending is a return-to-light beat rather than a dramatic cutscene.

See `STORY_BEATS.md`.

## Open-source/public-domain intake

V1 contains no third-party runtime source.

Research candidates are documented in `OPEN_SOURCE_INTAKE.md`:

- ShaderKit — MIT, effect/reference candidate only;
- Kenney Fish Pack — CC0, underwater ambience sprite source;
- Aqualand — CC0, underwater sprite/submarine reference pack.

Any direct asset import must be separately provenance-checked and selected narrowly rather than shipping complete packs.

## Why this is mechanically distinct

- **Afterglow Convoy:** forward escort / beacon protection.
- **Ash Harbor:** surface rescue and storm navigation.
- **Rainline:** internal train traversal / distributed power repair.
- **Signal Dive:** perception, sonar, depth pressure and sparse exploration.

## Compatibility / integration

- no network/wire/replay/database changes;
- no new runtime package dependency;
- no project.yml edit proposed;
- no product navigation hook proposed;
- iOS 15 semantic compatibility remains desirable, but iPhone 7 performance is not a design ceiling for this title.

## Acceptance criteria

- deterministic replay for identical seed/input;
- sonar contacts stable for identical state;
- sonar costs power and respects cooldown;
- beacon recovery requires proximity and low speed;
- hull/power/noise remain bounded;
- renderer visibly shows floodlight, fog, particles, sonar ring/blips, beacons and large unknown silhouettes;
- full Simulator build + XCTest + shader/runtime validation after Governor application.
