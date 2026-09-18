# V0.9.1 — A9 Health Lattice

## Purpose

Adapt the useful deterministic core of the DBH-LATTICE-CHIP V0.9 A9 into VeilLink as a local, advisory-only system health lattice.

## Kept from A9

- 144-state precompiled lattice topology.
- integer/fixed-point decision inputs; no floating policy state is required.
- P0 hard escalation.
- P1 / persistence / blocker / risk-floor interaction.
- GREEN / YELLOW / RED diagnostic light.
- L0–L5 advisory response levels and explainable reason codes.

## Removed from the database chip

- packet/release/contract/decision SHA fields from the A9 hot path;
- runtime attestation and V2.2/V2.3 packet codecs;
- Canonical/Freeze/Cutover database semantics;
- CPython extension and Linux `.so` accelerators;
- database-specific release identity / registration metadata.

These removals apply only to the adapted A9 diagnostic module. VeilLink E2EE, attachment SHA-256, BLE framing, trust and storage security remain unchanged.

## VeilLink inputs

A9 samples only local numeric/status telemetry: BLE quality/reconnect/queue/stall state, Agent availability/failure state, iOS thermal/low-power state, and cached SQLite integrity-check status. It never receives message plaintext, media contents, prompts, identity keys, session keys, pairing codes or unrestricted database access.

## Authority boundary

The adapted lattice is advisory only. It cannot disconnect peers, mutate queues, delete or rewrite storage, alter game state, change trust, pause production behavior, or invoke privileged Owner Mode actions.

## Storage behavior improvement

Settings no longer invokes `PRAGMA integrity_check` every time SwiftUI redraws the storage card. Database integrity is cached as `unchecked/ok/failed` and updated only when the user requests a local A9 storage check.

## Compatibility

- Protocol 4 unchanged.
- VLGM1 v1 unchanged.
- SQLite Schema V8 unchanged.
- iOS 15 target unchanged.
- iPhone 7 remains first-class.
