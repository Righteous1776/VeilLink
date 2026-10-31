# Risks / overlap

- Transport is protected: INBOX_ONLY only. Governor must integrate; this PR does not change product code.
- Existing draft PR #96 modifies many product modules and is under separate CI HOLD. Keep this drop separate; recheck its latest tree and any other transport proposals before selecting integration order.
- GATT 45-second timeout is intentionally conservative. Bluetooth restoration and iOS background execution can delay maintenance; cancellation depends on callbacks and is not hard realtime.
- Reconnect counter now spans physically connected but not GATT-ready attempts: intended to reduce churn, may extend recovery under intermittent service failures (30s cap).
- Metadata logs avoid BLE peer identifiers; local diagnostic retention still governed by existing DiagnosticLogStore.
- No claim of real dual-phone successful throughput, background survival or Apple SDK compilation based on Linux-only helper tests.
- Potential related but NOT changed: one-shot CoreBluetooth state restoration, permission/consent lifecycle, app-level BLE transport-ID / identity mapping, backpressure, and lost application-level ACKs.
