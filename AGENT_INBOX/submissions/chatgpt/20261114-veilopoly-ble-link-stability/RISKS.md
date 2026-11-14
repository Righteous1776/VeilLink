# Risks / Overlap / Limits

- **Protected scope:** transport and room liveness. Governor review and controlled integration required; this branch edits only its own Inbox directory.
- **Shared Bluetooth:** `VeilLink/Transport/BLETransport.swift` overlaps previous BLE reliability work (including PR #201). Reconcile on integration branch, do not blindly overwrite.
- **Veilopoly:** bridge/runtime and user-experience overlap prior PRs #184/#188 and possible unmerged room-control changes. Inspect latest accepted sources first.
- **Memory/latency:** preserving stalled queues reduces data loss but keeps bounded pending memory longer; admission limits remain unchanged and should be benchmarked on older phones.
- **Idle vs liveness:** a valid but stale encrypted session is not proof that the remote game peer is responding. UX labels this as sync delay; authoritative game-state hash and authenticated messages remain the sole basis for gameplay validation.
- **Backpressure polling:** peripheral fallback uses a 0.4s floor in addition to the OS callback; measure power/thermal under sustained full TX queue.
- **Actual disconnection:** system didDisconnect, deliberate disconnect and genuine GATT faults remain authoritative. It is incorrect and unsafe to treat a lost physical link as active forever.
- **Testing:** deterministic Swift policy regression tests are staged, but Apple SDK and two-device integration were unavailable in this execution. No performance improvement numbers can be claimed before measurement.
