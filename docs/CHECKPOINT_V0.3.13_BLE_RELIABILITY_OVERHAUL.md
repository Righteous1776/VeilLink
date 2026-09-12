# V0.3.13 BLE Reliability Overhaul

## Goal

Make delivery recover automatically inside the practical BLE operating envelope. This is application-level eventual delivery, not a claim that radio propagation can be absolutely guaranteed: RF obstruction, 2.4 GHz interference, iOS suspension and force-termination can still remove the link.

## Transport changes

- `CBCentralManagerScanOptionAllowDuplicatesKey` is enabled and RSSI samples are EMA-smoothed/throttled, so the transport has a live signal estimate instead of a one-time discovery RSSI.
- Connected central links also call `readRSSI()` every two seconds.
- `BLELinkReliabilityPolicy` classifies strong/good/marginal/weak links and selects smaller packet bursts plus longer inter-burst yielding as RSSI degrades. SE1 and iPhone 7 use more conservative pacing than SE2/13 Pro.
- Outbound transport queues have separate control and bulk lanes. Hello, text, attachment manifest, ACK and checkpoint traffic can advance ahead of large image fragments.
- Reconnect no longer stops after five failures. Backoff reaches a 30-second ceiling and continues while the user still wants the peer connected. Rediscovery and Bluetooth power restoration can wake reconnect immediately.
- Service-only advertising removes the local-name payload because discovery already filters by the 128-bit service UUID.
- A stalled central transmit queue automatically tears down/reconnects the physical link; a stalled peripheral notification queue drops only the stale transport frame and lets the persistent application outbox/checkpoint layer retransmit it.

## Session / delivery changes

- The signed Hello is retransmitted on a short 1/2/4/6/8-second schedule while authentication is incomplete. Receiving the peer Hello also echoes the local Hello again, closing the asymmetric “ours was lost, theirs arrived” window.
- A noisy link no longer marks a message failed after ten accepted BLE sends. The persistent outbox keeps retrying with capped backoff until acknowledgement/checkpoint or the existing seven-day expiry.
- A newly authenticated trusted session wakes all unpaused pending outbound rows immediately instead of waiting for an old retry timestamp.
- Text/control traffic uses the control-priority transport lane; attachment chunks remain bulk.

## Compatibility

Protocol 4, 48 KiB authenticated image chunks, cryptographic domains and SQLite Schema V8 are unchanged. This update does not increase iPhone radio transmit power and therefore does not promise a fixed number of meters.
