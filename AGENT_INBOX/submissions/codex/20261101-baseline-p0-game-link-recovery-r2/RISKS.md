# Risks — P0 game secure-session recovery R2

- This proposal corrects a primitive also referenced by the unintegrated PR #130 candidate. The Governor must not interpret this as approval to apply #130's refresh-only UI changes.
- The physical-link-alive scenario requires a two-device verification; the Linux environment cannot claim it passed.
- A nearby-peer record can be stale. The patch merely sends a bounded Hello and retains the existing handshake timeout; it does not treat the route as secure or queue a game action.
- No protocol, database, identity, key-management, signing or version change is proposed.
