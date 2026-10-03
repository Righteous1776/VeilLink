# PROPOSAL

## Objective

Preserve the useful Game Agent work from legacy direct PR #4 as an auditable Inbox proposal, while keeping integration authority with `VEILLINK-IG-001`.

The proposal has two separable product ideas:

1. **Local Game Mission Contracts** — deterministic, session-seeded side objectives for existing local mini-games.
2. **Orbit Relay / 轨道接力** — a lightweight, deterministic, local-only orbital maneuver game with no network or runtime asset dependency.

The Integration Governor may accept both, split them, rewrite them, or select only one.

## 1. Local Game Mission Contracts

Add a deterministic mission director that maps each existing `MiniGameKind` and session ID to one of three side objectives.

Design constraints:

- missions are meta-game only;
- they do not alter legal moves, official score, winner resolution, replay state, transport payloads, or compatibility contracts;
- mission progress is evaluated read-only from existing game state;
- progress is bounded to `0...1`;
- mission identity is deterministic per session using a stable byte hash;
- completed mission count may be surfaced in the local game hub.

The evaluator covers Gomoku, Xiangqi, Ludo, Tactical, Artillery, Light Trail, and Magnetic Hockey using state that already exists.

## 2. Orbit Relay / 轨道接力

Add a local-only Game Lab title built around deterministic fixed-step movement:

- 1000 × 700 logical field;
- central gravity well and exclusion radius;
- angle + power thrust input;
- finite fuel and stability;
- deterministic relay target generation from session ID and relay index;
- wall reflection with damping;
- relay capture scoring;
- first to three relays wins, with bounded-turn fallback scoring;
- a local bot that searches a finite coarse action grid and validates candidates through the same rule path as the player.

The game intentionally does **not** join `MiniGameKind` and does **not** touch VLGM/wire compatibility. It is an isolated local experiment until the Governor decides whether it deserves promotion to a network-capable game.

## 3. UI

The proposal adds:

- `LocalGameMissionStrip` for mission title/progress/detail;
- mission completion summary in the existing local game hub;
- `OrbitRelayLabView` with a code-rendered SwiftUI `Canvas` arena;
- existing VeilLink instrument primitives only, with no new binary assets.

## 4. Why this shape

This keeps game experimentation cheap in binary size and avoids adding model weights or network dependencies. Deterministic state transitions make replay/debugging and later multiplayer promotion easier if the game is accepted.

The local-only boundary is deliberate: product integration can evaluate gameplay quality first without expanding protocol or compatibility scope.

## Non-goals

- no version/build changes;
- no workflow changes;
- no release, IPA, signing or packaging changes;
- no protocol or replay schema changes;
- no database or identity changes;
- no A9/A10 governance changes;
- no replacement of Tactical V2 or the primary Guandu ownership lane;
- no attempt to resolve PR #10 overlap inside this submission.

## Integration recommendation

Treat `MiniGameViews.swift` as a Governor-owned merge point because PR #10 also modifies it. The seven additive files can be reviewed independently. If the mission UI or Game Lab entry conflicts with the accepted product-restoration UI, re-home the entry point rather than overwriting PR #10.
