# Proposal

## Goal

Add a lightweight deterministic abstract strategy prototype named Lattice Clash / 晶格争夺 for local Game Lab evaluation.

## Current problem

VeilLink's game surface benefits from variety, but new experiments should not increase binary size with model weights/assets or immediately expand multiplayer protocol scope. The previous Orbit Relay proposal explores deterministic physics; this proposal explores compact grid strategy with a different interaction model and substantially lower simulation cost.

## Proposed behavior

Lattice Clash uses a 7×7 board. Each side starts from two anchors on opposite edges. A legal move places one node in an empty cell within the eight-neighbor region of an existing friendly node.

After placement, every enemy node supported by at least three friendly neighboring nodes converts ownership. Conversion resolves in deterministic waves until no further captures exist. This creates visible chain reactions without randomness.

A side wins immediately on reaching 25 controlled cells, which is an absolute board majority. The board also has a bounded 45-placement horizon. If the opponent has no legal move, the active side retains the turn; if neither side can move or the horizon is reached, control count resolves the result.

## Architecture / implementation

### Rule core

LatticeClashGame.swift contains:
- value-semantic Sendable state types;
- deterministic legal-move generation;
- finite wave-based capture resolution;
- explicit majority / draw / score resolution;
- no timers, random numbers, networking, persistence or global state.

### Bot

LatticeClashBot performs bounded deterministic search over legal actions. Evaluation considers material difference, legal-move mobility and board centrality. Tie-breaking uses the lowest cell index, so identical state always returns identical output.

The bot applies candidate moves through the same rule engine as human play; it has no privileged mutation path.

### Lab UI

LatticeClashLabView.swift is an isolated SwiftUI experimental surface using only code-rendered gradients/shapes. It has no navigation registration in this proposal, avoiding overlap with current Game Lobby / MiniGameViews ownership. The board marks legal cells, ownership, last move, current turn, score, capture count and rules.

## User-visible impact

If later wired by the Integration Governor, users receive a short-session territory game that is distinct from the existing physics/arcade/tactical set. It is immediately understandable visually and has no download/runtime asset cost.

## Compatibility

- iOS 15-compatible SwiftUI primitives only;
- no MiniGameKind change;
- no VLGM/wire/replay schema change;
- no database migration;
- no version/build/release/workflow changes;
- no A9/A10 governance changes.

## Alternatives considered

1. Add the game directly to MiniGameKind and multiplayer transport: rejected for this iteration because that would expand compatibility scope and overlap existing integration surfaces.
2. Use a random procedural board: rejected because deterministic replay/debugging is more valuable.
3. Use a deep ML/Monte-Carlo bot: rejected due to binary/runtime cost and device-budget goals.
4. Modify MiniGameViews now: rejected to keep this drop entirely additive and conflict-light.

## Acceptance criteria

- same state always yields identical legal moves, captures and bot choice;
- illegal/wrong-actor moves do not mutate state;
- capture waves terminate and are reproducible;
- majority win and bounded fallback resolution are correct;
- bot-selected move is legal under the same engine;
- all proposed source paths are additive;
- no protected surface changes;
- full integration-time simulator build + XCTest pass before any product application.