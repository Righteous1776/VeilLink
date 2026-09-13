# V0.6.0 — Transport and Game Performance

## Scope

Performance and interaction polish only. Protocol 4, VLGM1 v1, encryption boundaries and SQLite Schema V8 are unchanged.

## BLE transport

- Generate final framing-v2 packets in one pass, avoiding the previous fragment-object array followed by a second encoded-packet array.
- Pace each send round with both a hard packet cap and a device/link-quality byte budget derived from the negotiated ATT packet size.
- Allow strong and good links to make materially more progress per scheduler round while preserving conservative delays for marginal and weak links.
- Record queue progress once per successful burst instead of reading the clock after every packet.
- Preserve CoreBluetooth backpressure, bounded per-peer queues, the control-priority lane, reconnect recovery and all existing wire bytes.

## Game reconstruction and rendering

- Build a session index once per off-main chat reload instead of reconstructing every session for every visible game card.
- Build Game Hub snapshots once per database refresh rather than during each SwiftUI body evaluation.
- Reconstruct a requested session from only its matching events.
- Replace tactical movement BFS `removeFirst()` churn with an indexed queue.
- Cache active units, selected unit and legal destinations for a tactical board render pass instead of repeating lookups for every hex.
- Add a compact turn-status rail, selected-counter lift and legal-area tint without bitmap assets or continuous animation.
- Continue respecting Reduce Motion and the existing SE1/iPhone 7 visual-performance policy.

## Verification gates

- BLE byte-budget, link-quality and direct-wire-packet tests.
- Session-index equivalence and all existing deterministic game/replay tests.
- Local repository, resource, protocol/schema and patch-whitespace audits.
- GitHub macOS XcodeGen, simulator build, complete XCTest, then unsigned Release `iphoneos` packaging.

## Device statement

These changes reduce application-side allocation, reconstruction and scheduling overhead. They do not claim a fixed Bluetooth speed: actual throughput still depends on negotiated ATT size, RF conditions, peer readiness and iOS scheduling. Real-device profiling on SE1, iPhone 7/7 Plus, SE2 and iPhone 13 Pro remains valuable after installation with a valid Apple signature.
