# Risks / Overlap

- **Protected subsystem:** `VeilLink/Transport/**`, `VeilLink/UI/NearbyView.swift`; Governor must explicitly integrate and review. Never auto-merge.
- **Source-level hypothesis, not field proof:** confirmed queue-stall teardown path exists, but the user-reported two-phone asymmetry has not been reproduced on actual devices; another cause may coexist.
- **Bounded memory/backpressure:** preserving central queue on live PHY trades destructive recovery for longer pending queues. Existing per-peer packet/byte admission caps still apply; app outbox is not cleared. A genuinely wedged CoreBluetooth stack may require an explicit user-requested reconnect; monitor stalls.
- **Probe load:** peripheral fallback adds one low-frequency retry per blocked peer (no stacked work items); measure power under many peers.
- **GATT timeout remains:** a real 45 s GATT handshake failure may still invoke `cancelPeripheralConnection`, which is different from weak RSSI. Further changes require measured evidence.
- **Overlaps:** pre-existing `AGENT_INBOX/submissions/ble-reliability-agent/20261031-ble-gatt-recovery-p0`, old game-link recovery proposals (PR #130/#134), any new BLE governor integration. No unilateral resolution.
- **A9 telemetry:** `PHY_CONNECTED` no longer counts as 'recovering' but stays operationally relevant via wanted intent; secure data readiness remains separate.
- **Device verification outstanding:** no macOS/Xcode/iPhone physical BLE tests performed; draft proposal only.
