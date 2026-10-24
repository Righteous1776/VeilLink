# Tests and evidence gates

- `VeilPeerCapabilityPolicyTests.swift`: legacy/new ACK Codable roundtrip and malformed extension rejection.
- `DatabaseStoreTests.testPeerCapabilitiesAreTrustedAndIdentityScoped`: trusted-key cache, local identity isolation, wrong public key, untrusted peer, SQLite integrity.
- Regression: CryptoEngineTests, DatabaseStoreTests, BackupAndStorageSafetyTests, BLETransportSafetyTests, LANTransportTests, RemotePairingTests.
- SQL: open v8 fixture, run v9 migration twice, verify v8 conversation/message rows and schema_migrations(9), force failure and check atomic rollback.
- Device: old v4 iPhone 7/iOS15 ↔ new v4.1 iPhone, both directions; reconnect, ACK replay/tamper, BLE fragment recovery, interrupted attachment, backup import.
- Gates: `git apply --check` + `git diff --check` against exact main; iOS 15 Simulator compile + XCTest, two real-device runs; protected-surface Governor review.

Status: source contexts checked against 8048b5c52b87eeb5d3622582da5728a8c2d64dda, patch proposed. Native Xcode/iOS CI and real-device execution NOT performed. No IPA output.
