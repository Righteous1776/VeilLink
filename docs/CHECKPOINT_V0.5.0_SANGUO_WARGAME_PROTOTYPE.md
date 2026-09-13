# VeilLink V0.5.0 — Sanguo Wargame Prototype

## Scope

V0.5.0 adds a fourth encrypted two-player game: `三国兵棋 · 官渡决战`.

The mode is an original lightweight historical strategy design built for VeilLink's existing two-peer BLE/E2EE architecture. It uses the visual language of hex-and-counter tabletop wargames, but does not copy a commercial game's board, counters, rulebook wording, values, or scenario setup.

## Gameplay model

- 7×9 offset hex battlefield.
- Cao is the host side; Yuan is the guest side.
- Six formations per side: command, two infantry formations, cavalry, ranged support, and supply.
- Each side receives two orders per activation.
- Terrain affects movement and defense; river hexes are blocked while fords remain passable.
- Supply is reconstructed by pathfinding from headquarters and surviving supply formations. Unsupplied formations receive reduced movement/combat effectiveness.
- Nearby command formations provide a small deterministic command-support modifier.
- Combat uses deterministic per-session/per-turn d6 values, so both peers independently replay the same encrypted event history to the same outcome.
- Guandu, Wuchao and Baima are objective hexes. Objectives score at the end of a full round.
- Match end: VP threshold, enemy headquarters occupation, enemy command loss, or eight-round comparison/tie.

## Transport / persistence

No new BLE packet family or database table is introduced. Tactical orders are represented by the existing VLGM1 `move` event with `from`/`to` coordinates; ending an activation uses a reserved tactical pass shape. The same E2EE session, ACK/outbox retry path, duplicate-action collapse, deterministic turn reconstruction, statistics, and replay pipeline are reused.

Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.

## Local acceptance

The LocalLab gate must pass:

- whole-tree Swift parse;
- Linux-compatible core typecheck including `TacticalGame.swift`;
- executable behavior harness for movement, supply and activation handoff;
- existing protocol/schema/iOS 15/iPhone 7 guards;
- cumulative patch apply/reverse/tree-equivalence validation.

macOS XcodeGen, Simulator build/XCTest, unsigned iphoneos Release build and two-real-device BLE play remain Work/macOS acceptance gates.
