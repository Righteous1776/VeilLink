# Sanitized owner blackbox audit, 2026-11-07

## Grounded facts from user's Build64 / iOS15.8.3 archive
- 8 runtime JSONL files, 17,797 unique events, 5 runtime session IDs.
- 1,081 `performance.main_thread_stall` events (median delay_ms 918, max 3,435); 1,008 labelled `games.lobby`. These are recorded events, not independent root causes.
- 3,095 `ble.link_snapshot`, 3,071 `session.nearby_peers` events. Legacy device low-power mode true, weak RSSI frequently ~-90 dBm. Unknown severity without radio repro.
- 459 `system.snapshot` with reason `brightness-change` (out of 678 total system snapshots), with frequent small 0.001 intensity increments and many duplicate samples. Current DeepTelemetry brightness NotificationCenter handler unconditionally calls `captureSystemSnapshot`, which performs a filesystem free-capacity query plus extensive UIKit/device metadata on MainActor.
- Off-device replay applying 2 s minimum and ≥0.02 delta on this ordered 5-session log would keep approximately **7/459** brightness snapshots. This is a filtering-model estimate, not a measured device speedup.
- Auxiliary MetricKit includes Build64 crash records with `0x8BADF00D` watchdog termination (scene creation and shutdown) and CPU exception diagnostics, as well as older Build60 records. Some artifacts may be historical/repeated; no symbolicated Swift stack or independent crash reproducibility established here.
- No plaintext messages, passwords or technical identity IDs are reproduced in this report.

## Already owned by existing unmerged proposals — DO NOT duplicate
- PR #137: DiagnosticLogStore background serialization, BLE/nearby snapshot damping, BLE reconnect.
- PR #145: startup SQLite integrity check deferral.
- PR #146: BLE audio coexistence.
- PR #139: message scroll anchoring and invite interaction.
- PR #64 (older Build60): root gesture/particle and stress test evidence.
- PR #152-156: image compression (unrelated to this telemetry P1).
- **This PR only fixes brightness-change full-system-snapshot amplification**; all other root causes remain for those owners/required tests.

## Evidence quality
- This ZIP is a bounded rolling export, not a full lifetime event history. Most recent runtime session differs from sessions with worst stalls.
- MetricKit diagnostic delivery/export timestamps need not equal actual crash onset; do not count retrieved artifacts as incident occurrence times.
