# E1 — 蓝牙启动与重复扫描幂等性修复

## Verified from main
- `AppModel.start()` may call `bluetooth.start()` more than once over app lifecycle.
- `BLETransport.start()` currently recreates RSSI polling and unconditionally requests scanning on each call, even if `isRunning` already true.
- `beginScanningIfPossible()` can reissue `scanForPeripherals` during recurring `refreshLinks()` while CBCentralManager is already scanning.
- CoreBluetooth service UUID and data framing remain unchanged.

## Proposed patch
- Early-return if the BLE transport is already running, retaining the existing RSSI Task, queued packets, connected peripherals, service and advertising state.
- Only call `scanForPeripherals` when `CBCentralManager.isScanning == false`. Existing poweredOn callback and explicit refresh still scan if stopped.
- No change to scan duplicate filtering, reconnect backoff, radio policy, wire schema, GATT characteristics, audio session, Apple background rules, or queue depth.
- This reduces redundant scan configuration/Task churn; does NOT guarantee headset coexistence, radio airtime isolation, battery-runtime improvement or the requested "five physical threads."

## Priority and isolation
Wait for Governor's merge-order arbitration with PR #137 (BLE recovery damping). Do not independently modify or adopt PR #137.
