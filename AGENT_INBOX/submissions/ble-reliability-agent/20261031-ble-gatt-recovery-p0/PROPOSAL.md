# P0 — PHY_CONNECTED must not mean GATT_READY

On current Build62 main, BLETransport resets `reconnectAttempts[id] = 0` in `didConnect` before characteristic discovery or notifications. A peripheral with broken/absent GATT service or rejected subscriptions is reconnected repeatedly at attempt-1 delay rather than bounded exponential backoff. `didDiscoverServices` with no matching service currently does nothing, leaving an indefinitely pending physical connection. A missing GATT callback likewise has no watchdog. `send` can choose a CBCharacteristic before it is notifying even though the app-level onConnected handshake is not yet raised.

This proposal:
1. Begins monotonic 45s GATT handshake tracking when physical central connection is established or restored. Uses the existing low-frequency maintenance loop, no new timer/threads.
2. ONLY resets reconnect-attempt count after a valid data-characteristic notify subscription succeeded; disconnect/failure clears pending handshake timestamps.
3. Enforces expected service and local characteristic capabilities (.notify and .writeWithoutResponse); cancels unsupported/empty discovery to use existing reconnect backoff.
4. If still PHY_CONNECTED after 45s with no GATT readiness, emits a bounded BLE diagnostic without identifiers, message plaintext, keys, pairing codes or application payload, and cancels the central connection. Existing didDisconnect drives reconnect.
5. Prevents premature central send when not subscribed and ignores stale didConnect after stop/explicit disconnect. Peripheral-responder transport remains unchanged.

No changes to BLEFragment format, wire version, codecs, encryption, identity, storage or A9/A10 authority.

## Limitations
This fixes deterministic state-machine paths in source but does **not** prove that two real devices communicate through a wall. Any physical radio/system background issue remains subject to on-device logs and RF testing. Preserve app-level outbox retransmission; physical link reset intentionally abandons incomplete transport frames.
