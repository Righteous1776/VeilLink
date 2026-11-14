# Veilopoly asymmetric-link false disconnect + shared BLE resilience (R1)

## User-observed failure and confirmed source mechanism
- One handset reports the Monopoly match connected; the other displays disconnected.
- `VeilopolyRoomLinkPolicy.shouldPauseGame` currently equates >15 seconds without an authenticated game packet to lost connectivity. The bridge runs this check every 5 seconds. The result can be asymmetric due to one-way delivery.
- On a still-connected GATT central channel, `BLETransport.recoverStalledTransportQueuesIfNeeded` currently empties queued frames and calls `recover(id)`, forcibly cancelling a live CoreBluetooth peripheral after 10/13/16 seconds without progress. A 45-second PHY→GATT watchdog also force-cancels an otherwise live PHY connection.
- `CBPeripheralManager.updateValue` backpressure currently only relies on a future ready callback; missing this callback can strand queued traffic.

## Proposed patch
1. Only pause game turns when the authenticated session is actually unavailable or the existing authoritative state-integrity checks require it. Quiet game traffic produces a non-destructive status probe; it is NOT a Bluetooth disconnect.
2. Use an injectable clock for deterministic bridge regression. Do not launch game-status/accept packets when secure peer session is unavailable.
3. Differentiate a failed low-priority status/resync probe from lost critical commit/proposal/snapshot transmissions. Probe-only congestion preserves current game readiness; critical failed sends still pause for integrity and authoritative resync.
4. Preserve packet queues and retry in place while CoreBluetooth/GATT confirms the channel remains usable. Only clean orphaned queues after an actually unavailable channel. Do not call `recover(id)` due solely to TX progress timeout or RSSI.
5. Retry the GATT service/characteristic/notify negotiation in place on a 45-second setup watchdog. Keep the state `PHY_CONNECTED` until data ready; errors still invoke existing failure path.
6. Add a bounded 250 ms fallback resend for peripheral notification backpressure without spin and without overriding CoreBluetooth's ready callback.

## Constraints
- No protocol 4 wire changes, no new permissions, no changes to chat encryption, pairing trust, identity keys, SQLite, A9/A10 or release/signing.
- Physical BLE link state and authenticated secure session remain separate truths; no UI may claim GATT ready merely due to RSSI or PHY.
- Maintain host authority, immutable game sequence/hash checks, persistent snapshots and no auto-play on guest disconnect.
- Observe real iOS background scheduling limits. TrollStore cannot guarantee unlimited CoreBluetooth execution.
