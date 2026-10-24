# Proposal

## Goal

Create a new class of VeilLink game experiments: **real-time 2D games with richer procedural rendering and stronger emotional pacing**, without increasing the app with large art/model assets or immediately expanding multiplayer protocol scope.

The first title is **Afterglow Convoy / 余烬护航**.

## Core fantasy

The player pilots a small skiff through a rain-soaked ruined corridor while escorting a fading signal beacon. The player is not merely protecting a score value: the beacon is a visible companion light that reacts to wind, impacts, shielding and progress.

The journey should feel tense during storms, quiet between impacts, and progressively warmer as the destination approaches.

## Proposed behavior

### Real-time movement

- fixed simulation step: 60 Hz;
- continuous vertical steering;
- automatic forward travel;
- momentum and damping rather than lane switching;
- deterministic hazard field generated from a session seed;
- bounded hull, beacon-energy and shield resources;
- optional held shield that trades shield charge for beacon/hull protection;
- deterministic ember caches that restore beacon/shield energy;
- terminal states: arrived, signal lost, hull lost.

### Emotional pacing

The journey has five non-blocking story beats tied to progress rather than menus/cutscenes. Example tone:

- “信标：我还在。别让风把我们分开。”
- “信标：旧频道里还有回声……像有人在等。”
- “信标：护盾留给你也可以。我会尽量撑住。”
- “信标：前面开始变亮了。不是闪电。”
- “信标：再往前一点。我们把这束光送回去。”

These lines are intentionally short. They should support play rather than interrupt it.

## Rendering architecture

### SpriteKit scene

`AfterglowConvoyScene` is proposed as the first dedicated real-time renderer in VeilLink.

It uses only procedural/code-generated visuals:

- three parallax ruin layers;
- deterministic debris / ember markers;
- high-rate rain emitter;
- moving fog bands;
- additive beacon glow;
- shield halo;
- low-energy spark emitter;
- tether line between skiff and beacon;
- impact flash + camera shake;
- lightning flashes derived from deterministic storm timing;
- dynamic storm/dawn color overlays;
- deterministic hazard streaming around the current world segment.

No bundled texture pack is required. Tiny rain/glow textures are created at runtime with UIKit drawing.

### Adaptive render tier

The scene proposes two tiers:

- **full**: denser rain, more fog, stronger glow/particles;
- **constrained**: lower birth rates, fewer layers/particles, weaker shake and fewer transient nodes.

The default recommendation uses Low Power Mode, processor count and physical memory as conservative heuristics. It is intentionally independent of staged/unaccepted render-budget proposals; the Integration Governor may later consolidate policies.

### SwiftUI lab wrapper

`AfterglowConvoyLabView` hosts the SpriteKit scene and provides:

- hull / beacon / shield / distance HUD;
- drag-based vertical steering;
- press-and-hold shield control;
- latest beacon line;
- end-state overlay and restart;
- Reduce Motion handoff to the scene.

It is not wired into existing navigation in this proposal.

## Why this differs from existing arcade games

Existing Artillery / Light Trail / Magnetic Hockey rendering is primarily SwiftUI Canvas and turn/segment oriented. Afterglow is continuous-frame and intentionally uses a dedicated game renderer with a persistent scene graph, emitters, parallax layers and camera effects.

## Compatibility

- iOS 15 target preserved;
- no network/wire/replay/database contract changes;
- no asset download or model weight;
- no project.yml edit proposed because SpriteKit/UIKit are system SDK frameworks;
- no existing game enum/entry change;
- pure local Game Lab experiment until separately approved.

## Alternatives considered

1. Continue with SwiftUI Canvas only: rejected because persistent particles, camera shake, layered scrolling and scene-graph effects become awkward and expensive to maintain.
2. Bundle hand-painted textures: deferred to avoid binary-size growth before gameplay acceptance.
3. Use Metal directly: rejected for V1 because SpriteKit provides sufficient 2D scene/particle performance with much lower integration cost.
4. Add networking immediately: rejected because emotional/gameplay validation should precede protocol expansion.

## Acceptance criteria

- deterministic core replay for identical seed + input;
- real-time steering and shield mechanics remain bounded and reproducible;
- hazard generation is seed-stable;
- visual renderer shows parallax, rain, fog, beacon glow, impact feedback and dynamic storm/dawn mood;
- low render tier materially reduces particle/node load;
- no existing product file is changed by the proposal;
- integration-time iOS Simulator build and full XCTest pass;
- real-device profiling on iPhone 7-class hardware before permanent entry wiring.
