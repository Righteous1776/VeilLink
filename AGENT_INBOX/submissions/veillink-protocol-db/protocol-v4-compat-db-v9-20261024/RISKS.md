# Risk and overlap review

- P0: wire protocol/database schema are protected surfaces. This PR is Inbox-only, not an integration authorization.
- Handshake version stays 4 because a forced v5 bump would strand installed old builds. The signed Hello is unchanged.
- Capability caching occurs only from a valid, already trusted and authenticated ACK associated with an outgoing message. Cache metadata cannot authorize access.
- Peer capability discovery is passive: a peer might have no cache entry until receiving ACK for normal traffic.
- v9 migration itself is atomic/idempotent; legacy v4-v8 steps in the repository are not refactored in this task.
- Existing backup snapshot/Keychain recovery pathway still requires on-device regression testing.
- Overlap: PR #53 contains a compatibility plan suggesting Wire v4 extension and DB v9. Governor must arbitrate. PR #50 storage control UI has adjacent behavioral surface; check during batch.
- CI/XCTest not run in this environment; never imply shipping quality before native tests.
- No binary assets, tokens, model weights, or release workflows in this submission.
