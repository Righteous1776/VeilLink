# V0.7.1 — Tactical Situation Awareness

## Scope

Deepen the existing 三国兵棋 experience without changing any state-transition rule, encrypted game event, transport protocol, or database schema. Old tactical histories must reconstruct to the same positions and outcomes as V0.7.0.

## Battlefield analysis

- Four install-local situation layers: 战场、补给、威胁、目标。
- Supply view derives the currently reachable supply network and flags unsupplied friendly counters.
- Threat view overlays both friendly and enemy attack radii and makes overlap zones visually obvious.
- Objective view shows Cao/Yuan local pressure around 官渡、乌巢、白马 without changing victory scoring.
- Selecting a command counter outlines its one-hex command-support radius.
- Any friendly or enemy counter can be inspected for current strength, attack, defense, movement, range, terrain, supply and command support.

## Combat decision flow

- Attacks are no longer committed by the first tap on an enemy target.
- The UI enumerates all 36 d6-vs-d6 combinations using the existing combat formula and displays defender-loss, destruction, attacker-loss and stalemate probabilities.
- Terrain, supply and command modifiers are shown before confirmation.
- The forecast intentionally does not expose the actual deterministic roll used by the current turn.
- Confirming an attack emits the exact same tactical move event as before.

## Orientation and rendering

- Guest/Yuan players see mirrored cell positions so their own formation is at the near edge. Tile content, Chinese labels and counters remain upright.
- The battlefield remains fully code-rendered; no bitmap or network asset dependency is added.
- Compact-device marker bounds remain within the SE1/iPhone 7 hex geometry.

## Compatibility

- Protocol 4 unchanged.
- VLGM1 v1 unchanged.
- SQLite Schema V8 unchanged.
- Tactical state transitions, deterministic die function, movement allowances, combat thresholds, objective scoring and victory conditions unchanged.
- Existing V0.5.0+ tactical sessions remain replay-compatible.

## Local validation

LocalLab covers Swift parsing, Linux-compatible core typecheck, executable tactical analysis harness, legacy-device guards, game layout geometry, Schema V8 smoke tests and package-layout simulation. True SwiftUI compilation, XCTest, simulator/device build and unsigned IPA packaging remain macOS/Work gates.
