# PROPOSAL — Relay API v1 reference service
## Current verified source of truth
The main app already contains a real client using `GET /v1/health`, `POST /v1/register`, `POST /v1/push`, `GET /v1/pull`, `POST /v1/ack`, with `JSONEncoder.dateEncodingStrategy = .millisecondsSince1970`. It has two selectable regions `domestic`/`international`, `smartDual` parallel sending for small frames, and both transports default **OFF with no server endpoint**. UI suggests Tencent CloudBase (domestic) and Cloudflare Workers/Durable Objects (international), but no corresponding backend source was located in the application repository.

## Concrete work staged for Governor
- Implemented Python 3 stdlib-only runnable HTTP reference server with the exact five endpoints.
- SQLite WAL, packet idempotency, re-register ownership protections, token SHA-256 hash storage and constant-time comparison, expired-record cleanup, separate read/write capabilities, 32-packet polling/ack, 512-packet mailbox capacity, encrypted-base64 payload only.
- Localhost-only binding by design; server stores no identity keys and no plaintext.
- Ten real offline integration/negative tests passed: health, end-to-end register-push-pull-ack, wrong token rejection, TTL expiry, duplicate packet prevention, size cap, invalid JSON/version, independent regional service, SQLite cold-load, HTTP method handling.
- All code is staged as plain text in `FILES/`; not shipped or run on a public endpoint.

## Release separation and API gate
- **Do not silently turn on Relay in the iOS app**. End-user use requires TLS with a real owner-approved address, meaningful abuse rate limiting, security audit and a deployed server on each region.
- Stage A: independently review and adapt this implementation to target cloud provider; Stage B: adversarial/load/privacy review; Stage C: run real iOS-to-iOS message and one-minute QR pairing across BOTH distinct endpoints; Stage D: Governor approves explicit endpoint configuration, only then new release branch includes it.
- Current product PR #119/#121 must pass full exact-head CI; do not merge this local reference as if it solved PR #119 or deployed a server.
