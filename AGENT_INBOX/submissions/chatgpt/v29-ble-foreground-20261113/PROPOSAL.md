# [P0 candidate] BLE foreground restoration without destroying reconnect backoff

## Owner symptom
Both iOS15 devices reported V29 Build66 real BLE recoverability issues. iPhone SE2 repeated `连接失败，准备重试`; blackbox exports ended with 0 connected peers. This is not proof of one underlying root cause; the secure-session/control handshake is a separate acceptance gate.

## Source-confirmed gaps
- `BLETransport.start()` and `centralManagerDidUpdateState(.poweredOn)` call `restoreWantedPeripheralsIfPossible()`, but `setForegroundActive(true)` calls `refreshLinks()` which does not. If CoreBluetooth retains .poweredOn without a new state callback while advertising is unavailable, a persisted wanted UUID can remain undiscovered and never proactively retrieved.
- Existing `restoreWantedPeripheralsIfPossible()` unconditionally executes `scheduleReconnect(... immediate:true)` for disconnected peers. That function cancels any previous `reconnectWorkItems[id]`, increments the reconnect attempt, and recomputes the delay. Calling restore on every foreground refresh without a guard would create a new storm/backoff reset.
- Connected restored peers trigger GATT service discovery and RSSI reads in the existing restoration path; doing this on every foreground refresh could duplicate discovery, cause latency and interfere with audio coexistence.

## Candidate mitigation
1. When a running app is foregrounded and has persisted wanted IDs, call restore in `reconnectDisconnectedOnly` mode. This performs CoreBluetooth `retrievePeripherals(withIdentifiers:)` even without new advertisements.
2. On a disconnected restored peripheral, only schedule immediate reconnect when no WorkItem is already pending. Preserve existing exponential backoff, stability reset and retry counters on every subsequent refresh.
3. When `reconnectDisconnectedOnly` is true, don't start GATT rediscovery/RSSI reads for an already connected peer. Preserve full GATT restoration during start and poweredOn state callbacks.
4. Add pure `BLELinkReliabilityPolicy` predicates and tests for foreground eligibility and backoff preservation.

## Deliberate nonchanges
No BLE service/characteristic UUIDs, packet fragmentation, encrypted SessionCoordinator, identity, Wire4 features, protocol capability negotiation, database, game lobby/Veilopoly bridge or timeout constants are modified. No plaintext fallback. User intent persists according to existing BLEConnectionIntentStore policy.

## Status
Candidate code only. It may improve foreground rehydration but will not solve a GATT handshake failure, iOS BLE 15 radio issue, mis-negotiated secure session or crashes by itself. All real hardware acceptance remains NOT_RUN and requires protected transport integration approval.
