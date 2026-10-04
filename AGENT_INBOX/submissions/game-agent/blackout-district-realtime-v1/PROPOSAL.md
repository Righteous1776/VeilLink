# Proposal — Blackout District / 熄灯街区

## Goal

Create a real-time top-down urban repair game where the emotional payoff is visible at city scale: the player does not merely fill a repair bar; repairing a node causes an entire district of windows, traffic infrastructure and grid lines to come back to life.

## Core loop

1. Storm surges progressively degrade a deterministic 9-node urban grid.
2. Faulted nodes break graph connectivity and darken downstream districts.
3. The player drives a maintenance truck through rain and flooded streets.
4. Puddles reduce traction and force slower route planning.
5. Repairs require stopping near a fault and holding the repair action.
6. Restored connectivity relights buildings and grid lines immediately.
7. Critical nodes such as the hospital, school district and primary substation receive stronger narrative emphasis.
8. Stabilizing the network for a sustained period wins the run.

## Simulation

- 60 Hz deterministic fixed-step state.
- 9 grid nodes, 10 graph edges.
- per-node demand, health, fault state, repair progress and power state.
- deterministic seed-driven surge selection.
- capacity/overload model that can cause secondary faults.
- graph traversal from the main substation to determine powered districts.
- continuous vehicle acceleration, heading and damping.
- puddle traction penalties.
- bounded 210-second storm window.
- stabilized / grid-collapse / time-expired outcomes.

## Rendering

### City

- top-down scrolling city;
- procedural building fallback;
- optional direct Kenney-derived textures when present;
- per-building window groups controlled by the actual grid node state;
- road network derived from power topology;
- puddle reflections;
- rain emitter;
- lightning exposure flashes;
- power-line glow;
- service-truck headlight cone;
- fault/repair particle bursts;
- Core Image Bloom around restored districts.

### Direct third-party ShaderKit use

This submission directly vendors:
- ShaderKitExtensions.swift
- SHKDynamicGrayNoise.fsh
- SHKRadialGradient.fsh
- ShaderKit MIT license

They are used for:
- moving grayscale storm/noise overlay;
- radial district glow around powered nodes.

The original MIT notice is preserved.

## Direct CC0 city-art policy

Kenney city resources are approved for direct integration. See THIRD_PARTY_ASSETS.md.

Inbox governance currently prohibits binary/large-artifact drops, so the assets are not physically committed in this proposal. The game code already looks for the agreed derivative resource names and falls back to procedural geometry if the assets have not yet been imported.

This means the Integration Governor can apply the code first, then add the approved CC0 sprites without changing gameplay code.

## Emotional design

The game uses short dispatch lines rather than cutscenes.

Examples:
- “关键节点 社区医院 失电。”
- “社区医院恢复。那一片灯又亮了。”
- “负载稳定。街区恢复常态供电。”

The strongest visual narrative is the city itself transitioning between darkness and warm occupied windows.

## Compatibility / boundaries

- iOS 15 source compatibility retained.
- no protocol/schema/storage changes.
- no network dependency.
- no model weights.
- no workflow/version/release changes.
- no existing game enum/navigation mutation in this drop.
- no iPhone 7 performance gate.

## Acceptance criteria

- same seed/input gives same state;
- grid stability stays bounded;
- faults can emerge deterministically;
- graph disconnects darken downstream districts;
- repair requires low-speed proximity;
- restored nodes relight districts;
- third-party shaders load from bundle with preserved MIT notice;
- Kenney asset aliases can replace procedural fallbacks without rule changes;
- full Xcode/iOS semantic build + XCTest before integration.
