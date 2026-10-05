# Proposal

## Goal

Create **Rainline / 雨线末班车**, a cinematic real-time 2D train-repair game that pushes the VeilLink game line beyond lightweight arcade scenes.

The game should combine:
- real-time movement inside an eight-car train;
- train-wide power failures;
- direct repair actions;
- a moving neon city outside the windows;
- layered rain and glass effects;
- short human story beats tied to the train's condition.

## Core fantasy

A storm-front has swallowed the city grid. The last train is still moving.

The player is the only maintenance engineer awake and able to move through all eight cars. Power faults appear as the train races through flooded elevated track. Each dark carriage is not just a meter: it contains visible passenger silhouettes and changes the mood of the entire train.

The emotional goal is to bring **all eight lit cars** to the final station.

## Gameplay

### Real-time fixed-step core

- 60 Hz deterministic simulation;
- player position spans all eight cars;
- left/right movement with acceleration/damping;
- deterministic electrical faults;
- each fault has severity and repair duration;
- repair only progresses while the player is in the affected car and moving slowly enough;
- train power drains from storm intensity + active faults;
- optional grid boost increases traction but sharply increases power drain;
- each car has its own light/power state;
- route progress depends on traction;
- terminal states: arrived, full blackout, traction stall.

### Decision pressure

The player must choose between:
- repairing a dark carriage;
- staying near the front to protect traction;
- using grid boost to keep moving;
- conserving train power so the rear cars stay lit.

A repaired car can restore some power and changes passenger/radio feedback.

## Rendering architecture

`RainlineLastTrainScene` is a persistent SpriteKit scene with a side-on cutaway of the entire train.

### Train interior

- eight separate carriage nodes;
- each car has its own warm interior light level;
- passenger silhouettes visible through lit windows;
- player character visibly moves between cars;
- active fault emits electrical sparks;
- car shells remain dark/cold while interior lighting responds continuously to `carPower`.

### Exterior city

- two city skyline parallax layers;
- many procedurally generated building silhouettes;
- sparse neon window lights;
- road/water reflection streaks;
- movement speed tied to train traction.

### Post-processing and glass

The proposal intentionally does **not** optimize for iPhone 7-class hardware. It keeps:
- SpriteKit + Core Image bloom on the train layer;
- dense rain emitter;
- full-screen glass-rain shader;
- lightning exposure flashes;
- neon reflection layer;
- multiple fault spark emitters;
- per-car lighting changes.

iOS 15 build compatibility remains desirable, but old-device performance is not a design constraint for this task.

### Glass-rain shader

A full-screen fragment shader creates:
- descending rain drops;
- thin streaks;
- cold-blue tint while train power is healthy;
- emergency red tint as grid power falls.

This is original project code and does not copy ShaderKit source.

## Emotional design

The train is treated as a moving shelter, not a score board.

Story beats are short and conditional:
- conductor / driver messages;
- passenger lines from repaired cars;
- visible windows relighting after repair;
- ending dialogue changes with the number of lit cars.

Examples:
- “窗外的楼都黑了，只有我们还在动。”
- “三号车厢：孩子不哭了。”
- “终点站：八节车厢，全灯抵达。雨还在，但门已经打开。”

See `STORY_BEATS.md`.

## Why this is mechanically distinct from Ash Harbor

Ash Harbor is external vehicle navigation/rescue.

Rainline is:
- interior traversal;
- fault prioritization;
- distributed power management;
- visible passenger-space state;
- stronger use of scene-wide lighting rather than open-water navigation.

## Compatibility / integration

- no network/wire/replay/database changes;
- no new package dependency;
- no project.yml edit in this proposal;
- no existing game enum/entry change;
- no product-tree mutation by the Agent Inbox branch.

## Acceptance criteria

- identical seed + identical input yields identical state;
- faults spawn deterministically;
- repairs only complete from the correct car while movement is controlled;
- trainPower, traction and carPower remain bounded;
- renderer visibly shows eight independently powered cars;
- outside city clearly reads as high-speed parallax;
- glass rain, bloom, lightning and fault sparks are visible;
- ending line changes according to train condition;
- full iOS Simulator build and full XCTest pass after Governor application.
