# V0.2 attachment resume checkpoint

This checkpoint upgrades image delivery to Protocol 3 application-level resumable transfer.

## Completed

- JPEG payloads up to 800 KB are no longer embedded in one encrypted chat envelope.
- Images are announced by an authenticated manifest, then sent as independently authenticated 48 KiB chunks.
- The receiver stores each confirmed chunk encrypted at rest in SQLite and replies with an authenticated `nextIndex` checkpoint.
- Sender and receiver checkpoints survive database reopen and BLE disconnects. A duplicate manifest or chunk is idempotent; conflicting duplicates are rejected.
- The sender advances only from receiver-confirmed progress. Lost checkpoints therefore cause at most a duplicate chunk, not skipped data.
- Final assembly verifies declared byte count and SHA-256 before creating the normal encrypted attachment file.
- Outgoing and incoming chat bubbles expose receiver-confirmed transfer progress.
- At most 16 incomplete inbound attachment transfers may coexist, bounding persistent half-transfer storage.
- Protocol 3 bumps handshake transcript, session KDF direction labels, and AEAD AAD domain labels so Protocol 2 ciphertext cannot be confused with the new transfer semantics.

## Verification boundary

The source tree passes Swift parser validation in the current non-macOS execution environment, and the standalone WireCodec type-check passes with a minimal `EncryptedPayload` stub. Full Xcode build/XCTest and two-real-iPhone fault injection remain required because CoreBluetooth, CryptoKit-on-iOS, Keychain and UIKit cannot be executed in this environment.
