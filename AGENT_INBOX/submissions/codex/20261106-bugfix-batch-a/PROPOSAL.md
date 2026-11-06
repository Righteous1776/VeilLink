# Proposal

## Goal

Reduce the measured main-thread logging load and high-frequency link telemetry, while preventing short-lived GATT readiness from prematurely erasing BLE reconnect backoff history.

## Current problem

DeepTelemetry captured 1,081 main-thread stalls averaging 917 ms and 3,095 link-snapshot events. `DiagnosticLogStore` is main-actor isolated, and Build64 routes 19 bridge log events through additional main-actor tasks. Link and peer publishers can also create frequent persistence work. Separately, `BLETransport` resets its reconnect attempt as soon as the GATT data channel becomes ready, so an unstable link can repeatedly return to the shortest existing delay.

## Proposed behavior

### A1 — serialized diagnostic persistence

- Move diagnostic encoding, buffering, disk append, refresh, clear, and auxiliary-artifact work onto one utility serial queue.
- Protect shared in-memory state with an `NSLock` and expose lock-backed snapshots for existing consumers, including `TelemetryConsoleView` through the unchanged `recentEntries` API.
- Coalesce `objectWillChange` delivery onto the main queue so SwiftUI observation stays on the UI thread.
- Preserve the external log API while making log submission asynchronous.
- Remove all 19 real Build64 bridge wrappers whose only purpose was to call `store.log` on `@MainActor`.

### A2 — link and peer snapshot gate

- Return immediately from the link-snapshot and nearby-peer sinks while the application is not active.
- Retain the existing fingerprint gate, then limit persisted snapshots to one per transport/key per 30 seconds.
- Count suppressed changes and emit `ble.link_oscillation` or `session.peer_churn` on the next allowed sample.
- Keep snapshot field contents and the package-specified event levels intact.

### A3 — reconnect damping

- Preserve every existing backoff delay and jitter constant (`0.75`, `1.5`, `3`, `6`, `12`, `20`, and `30` seconds).
- Do not reset `reconnectAttempts` merely because GATT notifications became ready.
- Reset immediately after valid peer traffic.
- Otherwise reset only after the data channel remains ready for the package-required 30-second stable interval.
- Centralize the 30-second threshold decision in `BLELinkReliabilityPolicy` and add boundary tests.

## Architecture / implementation

`DiagnosticLogStore` remains the only persistence owner. A serial queue orders writes and a state lock protects its buffer/cache and published snapshots. `RuntimeDiagnosticsBridge` calls the nonisolated submission API directly and owns the in-memory 30-second telemetry counters. `VeilAppLifecycleCoordinator` forwards the existing foreground state to that bridge. `BLETransport` tracks per-peer stable-start uptime and applies the policy from connection maintenance, reconnect scheduling, data-channel readiness, and validated traffic paths.

## User-visible impact

No intended UI, pairing, protocol, or stored-data-format change. Diagnostic console updates may arrive after the small asynchronous queue hop. On unstable Bluetooth links, retry pressure should damp instead of repeatedly returning to the minimum delay after transient readiness.

## Compatibility

- Target remains the Build64 source at `ccafebab147e069fbabfff579dbf323b0d54f191`.
- No SQLite schema migration is introduced.
- No Relay or Wire v4 compatibility surface changes.
- No version/build setting changes.
- The patch is source-only and reversible.

## Alternatives considered

- Keeping the store on `@MainActor` and only batching individual calls would retain the measured encoding/persistence burden on the UI executor.
- Unconditionally changing retry constants was rejected because the owner explicitly prohibited inventing timing changes; the existing schedule is preserved.
- Resetting reconnect state at GATT readiness was rejected because readiness alone does not prove a stable or traffic-carrying peer link.

## Acceptance criteria

- `PATCH.diff` applies cleanly to the exact base SHA with whitespace errors rejected.
- All seven changed Swift files parse, and the whole 447-file Swift tree parses.
- Diagnostic store passes strict-concurrency typechecking and a 100-call concurrent runtime harness with unique, ordered sequence numbers.
- Reconnect policy boundary harness passes before/at/after 30 seconds.
- BLETransport strict-concurrency typecheck has zero errors with Linux compatibility stubs.
- On the owner’s physical-device gate, link/peer log volume drops by at least one order of magnitude, telemetry export remains diagnosable, and Bluetooth-cutoff behavior does not regress.
- Batch B does not start until the Batch A physical-device gate is evaluated.
