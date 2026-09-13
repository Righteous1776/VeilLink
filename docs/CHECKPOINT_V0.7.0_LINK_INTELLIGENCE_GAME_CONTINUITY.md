# V0.7.0 — Link Intelligence & Game Continuity

## Scope

V0.7.0 is a local continuity/diagnostics iteration based exactly on GitHub V0.6.0 commit `ecf0a39f27eca51e5be7f176af0b318869736eef` (tree `712511b87a81862efbe5161997236c6f46fdd1aa`). Protocol 4, VLGM1 v1, encryption boundaries and SQLite Schema V8 are unchanged.

## Per-peer BLE link intelligence

- Track a throttled local snapshot for each known transport: connected/recovery state, smoothed RSSI, quality class, role, negotiated packet width, queue bytes/packets, control backlog, reconnect attempt and stall age.
- Expose a UI-only health score; it never changes crypto, retry or transport semantics.
- Keep diagnostics updates throttled so large image transfers do not turn SwiftUI into a packet-rate observer.
- Add a safe refresh path that re-runs discovery, advertising, connection-intent restore, stall checks and RSSI refresh without discarding queues.

## Game continuity

- Bind the game link indicator to the conversation's authenticated peer instead of the previous global `connectedPeerCount > 0` heuristic.
- Retain the most recent authenticated peer-to-transport mapping in memory while a secure session is reconnecting.
- Show the latest local game packet delivery state (queued/sending/paused/delivered/failed) beside the exact peer link state.
- Offer one-tap recovery for the known opponent transport. Game actions remain normal encrypted chat/outbox events and reconstruct from history exactly as before.

## Nearby + diagnostics UI

- Nearby peer cards show exact BLE state, quality, ATT width, queue pressure and health score.
- Settings adds a local link summary, a non-destructive refresh action and copyable diagnostics.
- The diagnostics report contains transport metadata only; no message bodies, attachment bytes, private/session keys or pairing codes.

## Release gates

- Full LocalLab parse/typecheck/harness and patch replay.
- GitHub/macOS XcodeGen + Simulator build + complete XCTest.
- Unsigned Release `iphoneos` packaging.
- Dual-real-iPhone BLE validation remains required for physical RF/throughput claims.
