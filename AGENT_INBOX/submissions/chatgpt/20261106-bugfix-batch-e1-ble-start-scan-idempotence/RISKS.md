# E1 boundaries and risks
- PR #137 modifies BLETransport.swift and reconnect reliability policy. Explicit file and behavior overlap; Governor must arbitrate and apply in the correct order. DO NOT independently resolve.
- `start()` now has strict idempotence: a caller that previously used repeat start to force discovery should use `refreshLinks()` (already public).
- `isScanning` only reports CoreBluetooth scan state; Apple's radio scheduler and headset connection are OS-managed. No claim of absolute BLE continuity, throughput gain or multi-queue radio isolation.
- This does not change `CBCentralManagerScanOptionAllowDuplicatesKey: true` because discovery freshness/telemetry may depend on it.
- Real battery impact and headset coexistence require on-device measurement.
- No product/main/CI/release/IPA changes; source proposed only, XCTest/device NOT_RUN.
