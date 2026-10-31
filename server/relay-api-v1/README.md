# VeilLink Relay API v1 — local reference implementation

**Development only. Not an Internet service.** This package was reviewed and staged from the accepted Inbox submission PR #124. It matches the current iOS client in \`VeilLink/Relay/InternetRelayTransport.swift\` but does not provision any domestic or international cloud endpoint.

## Commands

\`\`\`bash
cd server/relay-api-v1
python3 -m unittest discover -s . -p "test_*.py" -v
python3 relay_api.py --host 127.0.0.1 --port 8787 --db relay-local.sqlite3
curl http://127.0.0.1:8787/v1/health
\`\`\`

The server refuses to bind to public interfaces, and supports only an HTTP loopback developer process. It must **not** be routed through a public reverse proxy without a separate security review and full traffic-abuse, TLS, rate-limit, multi-process storage and backup plan.

## Contract

- GET \`/v1/health\` → \`{"status":"ok","version":1}\`
- POST \`/v1/register\`: \`version,mailbox,readToken,writeToken,expiresAt\`
- POST \`/v1/push\`: \`version,packetID,mailbox,writeToken,expiresAt,body\`
- GET \`/v1/pull?mailbox=...\`, \`Authorization: Bearer <readToken>\`
- POST \`/v1/ack\`: \`version,mailbox,readToken,packetIDs\`

JSON dates use **Unix epoch milliseconds**; the Swift \`Data\` ciphertext body uses standard JSON Base64. Separate mailboxes and read/write capability tokens, TTL cleanup, max 32 poll/ack and 512 buffered packets are implemented.

**Known unresolved issues:** no per-IP rate limiting or production IAM, no public TLS, SQLite is single-instance only, no cloud-provider transactional adaptation, no two-device live E2E test, no guarantee of delivery when iOS asynchronous send returns accepted, and no cross-region persistent dedup. This is not safe to expose publicly as-is.

### Gates

1. Full Python store and real localhost HTTP tests green; native iOS client JSON contract matched.
2. Independent secure cloud port for both regions, real HTTPS endpoint set by Owner, strict origin/capability/rate controls, logs without private tokens.
3. Physical iOS ↔ iOS tests of register, push, pull, ack, retry and outage; before promoting the API to a public release.
4. Unchanged disabled-by-default behavior until 1-3 are met. Do not bundle sample Python into the iOS app, mutate app DB, wire or release tooling.
5. This branch is separate from the pending VeilLink 27.2 Build64 offline Gomoku release candidate.
