# Integration acceptance plan

1. Verify actual owner-delivered ZIP SHA-256: 61b4bb8cdb6070b2d5c47100bff9a0f3c1ebba67471b57db6174e62aa6250a3d; extract and apply its full add-only PATCH.diff against 501ef814a0a9bea41419fe2d9f48315371b30320.
2. This Inbox PATCH.diff adds only a human-auditable documentation contract. It is not the source patch.
3. Full project XcodeGen on macOS targeting iOS15 + XCTest. Confirm each of 20 IDs produces sensible output for default sample and rejects malformed input.
4. On iPhone7 iOS15.8.3: UI TextEditor, layout, dark/light, navigation, copy, touch hit testing with PR #64–#66; ensure heavy operations do not block main thread.
5. Future device adapters may provide read-only telemetry snapshots but must not autonomously change BLE route, Wire v4, SQLite/Keychain, outgoing queues, or identities.
6. Do not enable a ToolCenter navigation link before PR #65 is reconciled by Governor; no IPA workflow dispatch until owner approval.
