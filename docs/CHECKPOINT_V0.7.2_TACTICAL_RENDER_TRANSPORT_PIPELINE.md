# V0.7.2 — Tactical Render & Transport Pipeline

## Scope

This checkpoint is a focused performance iteration over V0.7.1. It does not add a new protocol, database migration or gameplay rule.

## Tactical board

- Build one `TacticalSituationSnapshot` per SwiftUI body pass for active counters, supply, command zones, objectives and threat maps.
- Cache the fixed 7×9 board's neighbor and distance tables.
- Render threat concentration levels so overlapping coverage is visible without affecting deterministic combat.
- Mark hex cells equatable so unchanged cells can skip redundant body work.
- Preserve guest-side orientation, combat forecast, movement rules and historical session reconstruction.

## BLE transport

- Encode framing-v2 packets directly into the selected peer priority queue.
- Reuse queue storage and compact consumed prefixes before appending.
- Avoid allocating an intermediate `[Data]` plus a second traversal to count bytes.
- Preserve packet bytes, fragmentation limits, control priority, backpressure, stall detection and reconnect behavior.

## Compatibility gates

- iOS 15 deployment target and iPhone 7 compatibility remain unchanged.
- Protocol 4, VLGM1 v1 and SQLite Schema V8 remain unchanged.
- XcodeGen, simulator build, complete XCTest and Release `iphoneos` unsigned IPA are required before release.
