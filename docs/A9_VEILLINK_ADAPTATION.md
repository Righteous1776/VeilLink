# A9 → VeilLink Adaptation Record

## Source reviewed

Source package supplied by the project owner: `DBH-LATTICE-CHIP V0.9 A9` (database-health arbitration chip).

Observed source properties retained as design facts:

- 144-state deterministic lattice.
- Diagnostic light: GREEN / YELLOW / RED.
- Severity counts: P0 / P1 / P2 / P3.
- Persistent-yellow threshold: 3 evaluation runs.
- Red-risk threshold: 2800 basis-point units (28 risk points).
- P0 hard escalation to L5.
- RED + blocker → L4.
- RED without blocker → L3.
- YELLOW + P1/persistence → L2.
- advisory-only authority boundary.

## Removed database-integration shell

The following source concepts are intentionally **not** carried into the iOS runtime:

- DBH arbitration packet V1/V2/V2.2/V2.3 schemas;
- packet SHA-256 and decision SHA-256;
- release identity SHA, contract SHA and capability-negotiation SHA;
- runtime attestation and attestation sequence binding;
- Canonical write / Freeze / Cutover vocabulary;
- CPython extension `_dbh_a9_fast`;
- Linux `.so` native accelerators;
- secure JSONL packet codec;
- release guard / build-binary digest checks in the runtime path.

Those mechanisms protected a cross-module database arbitration boundary. VeilLink's A9 monitor runs inside one app process over typed local telemetry, so carrying that transport/attestation shell into the hot path would add cost without strengthening the relevant boundary.

This removal does **not** remove or weaken VeilLink cryptography. Protocol 4 E2EE, secure-session validation, attachment SHA-256, encrypted SQLite content, backup integrity and BLE framing/replay defenses remain independent and unchanged.

## New typed telemetry mapping

| VeilLink source | A9 signal examples | Severity mapping |
| --- | --- | --- |
| SQLite cached integrity result | integrity check failed | P0 |
| BLE control queue | stalled >=20s / >=8s | P1 / P2 |
| BLE reconnect | >=6 / >=3 / active | P1 / P2 / P3 |
| BLE control backlog | >=64 / >=16 packets | P1 / P2 |
| BLE total queue | >=2MB / >=512KB | P2 / P3 |
| BLE RF quality | weak / marginal | P2 / P3 |
| BLE local H score | below 30 | P2 |
| Agent runtime | failed / unavailable / cooling | P2 / P3 / P3 |
| iOS thermal state | critical / serious / fair | P1 / P2 / P3 |
| Low Power Mode | enabled | P3 |

No message plaintext, image/video contents, prompts, identity keys, session keys or pairing codes enter A9.

## Risk and health normalization

VeilLink uses integer policy math:

- P0 = 40 risk points
- P1 = 12
- P2 = 4
- P3 = 1
- `riskBP = riskPoints * 100`
- `healthBP = max(0, 1000 - P0*500 - P1*160 - P2*70 - P3*20)`

Signal selection:

- RED: any P0, risk >= 2800, or health < 500.
- YELLOW: any non-P0 issue or health < 800.
- GREEN: otherwise.

The 144-state A9 lattice then applies P0/P1/blocker/persistence/risk-floor rules unchanged in topology.

## Runtime authority

`VeilA9HealthMonitor` is advisory-only. It cannot:

- disconnect/reconnect BLE;
- consume/drop/reorder queues;
- rewrite SQLite;
- delete messages or attachments;
- change trust;
- move game pieces or alter scores;
- change Agent runtime state;
- invoke Owner Mode actions.

The app may later choose to display recommendations derived from A9, but any automated mitigation must be designed as a separate, explicit policy layer.

## iPhone 7 budget

- no Python;
- no native third-party `.so`;
- no cryptographic digest work inside A9 sampling;
- classifier and lattice are pure Swift integer/status operations;
- health refresh is debounced;
- SQLite integrity check is on-demand instead of SwiftUI-redraw-driven.
