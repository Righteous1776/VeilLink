# Test plan — P0 game secure-session recovery R2

1. `git apply --check PATCH.diff` → patch applies to the stated baseline → required before triage.
2. Static review: confirm `recoverSecureSession` selects its transport before mutating `sessions` or preferred bindings; confirm the existing game-hub and game-session recovery callers retain their refusal to persist a command while no secure session exists.
3. Two-device BLE test: pair two trusted devices, retain the physical GATT connection, invalidate only the secure session, tap invite and then move. Verify a Hello is transmitted on the existing transport, a secure session returns, and no duplicate game command is stored.
4. BLE disconnected test: repeat with the physical connection dropped. Verify recovery preserves connection intent, refresh begins, and the user sees no false "sent" state.
5. LAN-only and relay-only tests: verify a direct recovery starts when a remembered route exists and that the fallback refreshes do not create first trust.
6. Run the full XCTest target and an iOS simulator build after the Governor applies the patch. Simulator success is not a substitute for the two-device tests.
