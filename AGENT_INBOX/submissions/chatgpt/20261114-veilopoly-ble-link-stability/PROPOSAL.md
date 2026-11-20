# Implemented Fix — Veilopoly liveness and global BLE queue recovery

## Reproduced source-level causes
1. `VeilopolyRoomLinkPolicy.shouldPauseGame` treated silence >15s as game offline, despite a still-ready encrypted session.
2. `BLETransport.recoverStalledTransportQueuesIfNeeded` discarded central outbound frames and called `recover(id)` after a 10–16s TX stall, which cancels a live CoreBluetooth connection. Peripheral TX stalls discarded queued frames.
3. `drainPeripheralQueue` relied exclusively on CoreBluetooth's ready callback after `updateValue` returned false, with no bounded fallback.

## Implemented source changes (not documentation-only)
- Keep the verified `secureSessionReady` predicate as the trigger for game pause; game-packet silence triggers a status/sync probe instead of disconnect. A stale peer is NOT called connected just because RSSI is good: network readiness still requires authenticated packets and matching game hashes.
- Make `VeilopolyMultiplayerBridge.tick(now:)` deterministic for regression tests; keep room and chat session on idle and display "保留加密连接并继续同步" instead of false offline.
- Replace queue-stall-triggered central `recover(id)` with bounded flow-control retries against an actually ready GATT channel; never reset the central queued fragments as an idle heuristic.
- Preserve pending peripheral packets on stall and retry `updateValue` with CoreBluetooth ready callback + 0.4s fallback after buffer backpressure.
- Use 2s rate limiting for stalled queue re-probes, retain quality-adaptive thresholds, and clear probe state on real disconnection or completed queue drain.
- Add pure policy and host-bridge tests, preserving signed sessions, wire protocol, identity, DB schema, A9/A10 and other BLE capabilities.

## Strict distinction
`CBCentralManager.didDisconnectPeripheral`, explicit user disconnect, notification subscription failure, and true GATT handshake failure still trigger genuine reconnection/failure handling. This fix **does not** force iOS to hold a radio link that the OS has dropped, nor claim persistent iOS background privileges.

## Acceptance criteria
- >15s quiet but secure Veilopoly lobby/game: still network-ready if previously synchronized, show "sync delayed" separately.
- Intentional BLE link loss: genuine disconnect callback still respected; old link does not remain falsely connected.
- >10–16s low-throughput queue: pending frames survive and never initiate `cancelPeripheralConnection` only due to congestion.
- Peripheral buffer pressure: queued packet remains until CoreBluetooth accepts it; retries do not spin.
- Two iPhones with poor signal: no premature game offline state or asymmetric status simply from a stagnant queue.
