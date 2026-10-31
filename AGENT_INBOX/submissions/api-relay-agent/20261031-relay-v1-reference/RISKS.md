# RISKS — unshipped reference backend
- P0: This is a **localhost-only** developer reference, not an internet-exposed service; no durable cloud storage replica, DDoS/per-IP rate limiter, production IAM, TLS termination or observability. Its binding explicitly rejects non-loopback.
- P0: A valid public register endpoint without global rate limiting could be abused to exhaust SQLite storage. This implementation is NOT suitable for direct public deployment.
- P0: Per-mailbox HMAC-derived secrets are client capabilities; server receives them over TLS in real deployment. Do not copy tokens into logs or telemetry; enforce HTTPS before allowing public traffic.
- P0: The app's `send(_:,to:,priority:)` returns `.accepted` before HTTP async delivery succeeds. Outbox retry/ack must be validated end-to-end before calling it guaranteed delivery.
- P1: TTL clock skew, unavailable endpoints, transient errors, simultaneous parallel sends and cross-region dedup require real devices and network fault injection.
- P1: SQLite single-instance store is inappropriate for distributed Cloudflare Durable Objects or CloudBase until ported to provider-specific transactional storage and reviewed.
- P1: A successful local API contract does not repair unrelated Gomoku PR #119/#121 CI failures or authorize new IPA.
- No changes to protected protocols, database schema, identity/key management or workflows have been made in this Inbox proposal.
