# Risk and overlap

- Protected surfaces: Keychain, SQLite/schema, BLE wire protocol, entitlements, signed IPA and versioning. This patch does not mutate them.
- The iPhone7 database screen is a fail-closed Keychain access failure, not proof of DB deletion. Never reset/re-key existing data. Signing team and keychain-access-groups must be checked separately.
- Prior merged changes #54 (particles), #57 (Troll readiness), #63 (pre-consent diagnostic) overlap by subsystem. Governor must re-review current main; no silent acceptance.
- Particle touch trails intentionally disappear to restore drag gestures. Subtle noninteractive navigation bursts remain.
- iOS15 failure view may need layout/scroll adaptation; requires real-device UI gate.
- iPhone7 collaborative protocol warnings are unresolved by this patch. No claim of universal connection repair.
- These proposed changes were produced without Xcode/macOS or hardware testing. Do not merge solely on static reasoning.
- No user black-box ZIP, device identifiers, passwords, plaintext, or cryptographic keys were uploaded.
