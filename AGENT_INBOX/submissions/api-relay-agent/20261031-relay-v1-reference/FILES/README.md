# VeilLink Relay API v1 — local contract reference

This is a runnable **localhost-only reference server** and offline test suite for VeilLink's existing iOS `InternetRelayTransport.swift` and `VeilRemotePairingCoordinator.swift`. It is **NOT deployed**, **NOT production ready**, and does **NOT** turn the disabled/default-unconfigured Internet Relay in the iOS app into a live service.

No third-party dependencies are required (CPython 3.10+). Each regional service needs its **own independent storage**. The server stores only opaque, encrypted `Data` envelope bytes in base64, hashed per-mailbox read/write bearer tokens, expiry timestamps, and random packet IDs. No identity, chat plaintext, phone information, or location fields.

```bash
cd server/relay-api-v1
python3 -m unittest -v test_relay_api.py
python3 relay_api.py --db relay-local.sqlite3 --host 127.0.0.1 --port 8787
curl http://127.0.0.1:8787/v1/health
```

## Client contract (Swift JSONEncoder .millisecondsSince1970)

| Method | Path | Body / authorization | Response |
|---|---|---|---|
| GET | `/v1/health` | none | HTTP 200; `{"status":"ok","version":1}` |
| POST | `/v1/register` | JSON `{version:1,mailbox,readToken,writeToken,expiresAt}` | HTTP 200 JSON `{ok:true}`; conflict 409 |
| POST | `/v1/push` | JSON `{version:1,packetID,mailbox,writeToken,expiresAt,body}`; body is base64 of opaque bytes | HTTP 200 JSON `{ok:true}`; unauthorized 403 |
| GET | `/v1/pull?mailbox=...` | HTTP `Authorization: Bearer <readToken>` | HTTP 200 JSON `{version:1,packets:[{packetID,body,expiresAt,receivedAt}]}`; max 32 items |
| POST | `/v1/ack` | JSON `{version:1,mailbox,readToken,packetIDs}` | HTTP 200 JSON `{ok:true}` |

`expiresAt` and `receivedAt` are **integer milliseconds since Unix epoch**, not ISO text. Client `Data` encodes as base64 by default. `packetID` is an ordinary RFC 4122 UUID string; the mailbox/read/write tokens are per-provider HMAC-derived values. HTTP 2xx/4xx/5xx semantics are meaningful to the Swift client, but client currently does not report detailed server JSON errors.

**Production acceptance gate (not fulfilled):** a deployed TLS endpoint + secure storage/backups, per-IP and per-mailbox rate limiting and quotas, multi-process concurrency / cross-region behavior, control-plane IAM, abuse resistance, anti-replay and packet TTL, full threat model, independent end-to-end iPhone-to-iPhone remote QR and message roundtrip, failure simulation, and owner-approved release workflow. This local service intentionally refuses non-loopback binding; do not just expose it to the internet or claim the API is online.