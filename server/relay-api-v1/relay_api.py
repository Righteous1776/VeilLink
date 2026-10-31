#!/usr/bin/env python3
"""VeilLink v1 opaque-message relay reference backend (localhost by default).

Uses only Python stdlib + SQLite. This is a reference staging service, NOT an
approved public deployment. Run behind HTTPS, with ingress-rate limits and
operational monitoring before any production exposure. No decryption keys,
identities, user profiles, or plaintext messages are stored.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from hmac import compare_digest
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
import sqlite3
from threading import RLock
import time
from urllib.parse import parse_qs, urlparse

TOKEN = re.compile(r"[a-zA-Z0-9_-]{16,128}\Z")
MAILBOX = re.compile(r"[a-zA-Z0-9_-]{16,128}\Z")
PACKET = re.compile(r"[a-zA-Z0-9_-]{8,100}\Z")  # UUID has hyphens
MAX_BODY_BYTES = 512 * 1024
MAX_FRAME_BYTES = 256 * 1024
MAX_MAILBOX_PACKETS = 512
MAX_ACK_RECEIPTS_PER_MAILBOX = 65536  # bounded research-only mailbox receipts
MAX_REGISTER_TTL_MS = 10 * 24 * 60 * 60 * 1000
MAX_PACKET_TTL_MS = 7 * 24 * 60 * 60 * 1000


def reject(status: int, code: str) -> tuple[int, dict]:
    return status, {"error": code}


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode("ascii")).hexdigest()


def require_string(data: dict, key: str, pattern: re.Pattern) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ValueError("invalid_" + key)
    return value


def require_version(data: dict) -> None:
    if type(data.get("version")) is not int or data["version"] != 1:
        raise ValueError("unsupported_version")


def require_expiry(data: dict, now_ms: int, maximum_ttl_ms: int) -> int:
    value = data.get("expiresAt")
    if type(value) is not int or not (now_ms < value <= now_ms + maximum_ttl_ms):
        raise ValueError("invalid_expiry")
    return value


class RelayStore:
    """A single-instance storage contract; one SQLite DB per regional provider."""

    def __init__(self, path: str = ":memory:", clock=None):
        self.clock = clock or (lambda: int(time.time() * 1000))
        self.lock = RLock()
        self.db = sqlite3.connect(path, isolation_level=None, check_same_thread=False)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA busy_timeout=5000")
        self.db.execute("PRAGMA foreign_keys=ON")
        with self.lock:
            self.db.execute("""CREATE TABLE IF NOT EXISTS mailboxes (
                mailbox TEXT PRIMARY KEY, read_hash TEXT NOT NULL, write_hash TEXT NOT NULL,
                expires_ms INTEGER NOT NULL)""")
            self.db.execute("""CREATE TABLE IF NOT EXISTS packets (
                mailbox TEXT NOT NULL REFERENCES mailboxes(mailbox) ON DELETE CASCADE,
                packet_id TEXT NOT NULL, body_b64 TEXT NOT NULL,
                expires_ms INTEGER NOT NULL, received_ms INTEGER NOT NULL,
                PRIMARY KEY (mailbox, packet_id))""")
            self.db.execute("CREATE INDEX IF NOT EXISTS packet_expiry_idx ON packets(expires_ms)")
            self.db.execute("""CREATE TABLE IF NOT EXISTS acknowledged_packets (
                mailbox TEXT NOT NULL REFERENCES mailboxes(mailbox) ON DELETE CASCADE,
                packet_id TEXT NOT NULL, body_sha256 TEXT NOT NULL,
                expires_ms INTEGER NOT NULL,
                PRIMARY KEY (mailbox, packet_id))""")
            self.db.execute("CREATE INDEX IF NOT EXISTS acknowledged_expiry_idx ON acknowledged_packets(expires_ms)")

    def close(self) -> None:
        with self.lock:
            self.db.close()

    def _prune(self, now_ms: int) -> None:
        self.db.execute("DELETE FROM mailboxes WHERE expires_ms<=?", (now_ms,))
        self.db.execute("DELETE FROM packets WHERE expires_ms<=?", (now_ms,))
        self.db.execute("DELETE FROM acknowledged_packets WHERE expires_ms<=?", (now_ms,))

    def _authorize(self, mailbox: str, key: str, column: str, now_ms: int) -> bool:
        record = self.db.execute(
            "SELECT read_hash, write_hash FROM mailboxes WHERE mailbox=? AND expires_ms>?",
            (mailbox, now_ms),
        ).fetchone()
        if record is None:
            return False
        stored = record[0] if column == "read" else record[1]
        return compare_digest(stored, token_hash(key))

    def request(self, method: str, path: str, query: str = "", headers: dict | None = None,
                body: bytes = b"") -> tuple[int, dict]:
        headers = {k.lower(): v for k, v in (headers or {}).items()}
        now = self.clock()
        if len(body) > MAX_BODY_BYTES:
            return reject(413, "body_too_large")
        if method == "GET" and path == "/v1/health":
            return 200, {"status": "ok", "version": 1}
        if path not in {"/v1/register", "/v1/push", "/v1/pull", "/v1/ack"}:
            return reject(404, "not_found")
        if method != ("GET" if path == "/v1/pull" else "POST"):
            return reject(405, "method_not_allowed")
        try:
            if method == "POST":
                if not headers.get("content-type", "").split(";")[0].strip() == "application/json":
                    return reject(415, "content_type")
                data = json.loads(body)
                if not isinstance(data, dict):
                    raise ValueError("invalid_object")
                require_version(data)
            else:
                data = {}

            with self.lock:
                self.db.execute("BEGIN IMMEDIATE")
                try:
                    self._prune(now)
                    if path == "/v1/register":
                        result = self._register(data, now)
                    elif path == "/v1/push":
                        result = self._push(data, now)
                    elif path == "/v1/pull":
                        result = self._pull(query, headers, now)
                    else:
                        result = self._ack(data, now)
                    self.db.execute("COMMIT")
                    return result
                except Exception:
                    self.db.execute("ROLLBACK")
                    raise
        except (TypeError, ValueError, json.JSONDecodeError, UnicodeError, binascii.Error) as exc:
            return reject(400, str(exc)[:80] or "invalid_request")

    def _register(self, data: dict, now: int) -> tuple[int, dict]:
        mailbox = require_string(data, "mailbox", MAILBOX)
        read_token = require_string(data, "readToken", TOKEN)
        write_token = require_string(data, "writeToken", TOKEN)
        expires = require_expiry(data, now, MAX_REGISTER_TTL_MS)
        if compare_digest(read_token, write_token):
            return reject(400, "separate_read_and_write_tokens_required")
        old = self.db.execute(
            "SELECT read_hash, write_hash FROM mailboxes WHERE mailbox=?", (mailbox,)
        ).fetchone()
        read_hash, write_hash = token_hash(read_token), token_hash(write_token)
        if old is not None:
            if not (compare_digest(old[0], read_hash) and compare_digest(old[1], write_hash)):
                return reject(409, "mailbox_owned")
            self.db.execute("UPDATE mailboxes SET expires_ms=? WHERE mailbox=?", (expires, mailbox))
            return 200, {"ok": True}
        self.db.execute(
            "INSERT INTO mailboxes(mailbox,read_hash,write_hash,expires_ms) VALUES (?,?,?,?)",
            (mailbox, read_hash, write_hash, expires),
        )
        return 200, {"ok": True}

    def _push(self, data: dict, now: int) -> tuple[int, dict]:
        mailbox = require_string(data, "mailbox", MAILBOX)
        key = require_string(data, "writeToken", TOKEN)
        packet = require_string(data, "packetID", PACKET)
        expires = require_expiry(data, now, MAX_PACKET_TTL_MS)
        encoded = data.get("body")
        if not isinstance(encoded, str) or len(encoded) > (MAX_FRAME_BYTES * 4 // 3 + 8):
            return reject(413, "invalid_packet_size")
        try:
            wire = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error):
            return reject(400, "invalid_base64")
        if not (1 <= len(wire) <= MAX_FRAME_BYTES):
            return reject(413, "invalid_packet_size")
        if not self._authorize(mailbox, key, "write", now):
            return reject(403, "unauthorized")
        consumed = self.db.execute(
            "SELECT body_sha256, expires_ms FROM acknowledged_packets "
            "WHERE mailbox=? AND packet_id=?", (mailbox, packet),
        ).fetchone()
        if consumed is not None:
            digest = hashlib.sha256(wire).hexdigest()
            if not compare_digest(consumed[0], digest) or consumed[1] != expires:
                return reject(409, "packet_id_conflict")
            return 200, {"ok": True, "duplicate": True}
        existing = self.db.execute(
            "SELECT body_b64, expires_ms FROM packets WHERE mailbox=? AND packet_id=?",
            (mailbox, packet),
        ).fetchone()
        if existing is not None:
            if existing[0] != encoded or existing[1] != expires:
                return reject(409, "packet_id_conflict")
            return 200, {"ok": True, "duplicate": True}
        receipts = self.db.execute(
            "SELECT COUNT(*) FROM acknowledged_packets WHERE mailbox=?", (mailbox,)
        ).fetchone()[0]
        if receipts >= MAX_ACK_RECEIPTS_PER_MAILBOX:
            return reject(429, "ack_receipt_capacity")
        total = self.db.execute("SELECT COUNT(*) FROM packets WHERE mailbox=?", (mailbox,)).fetchone()[0]
        if total >= MAX_MAILBOX_PACKETS:
            return reject(429, "mailbox_capacity")
        self.db.execute(
            "INSERT INTO packets(mailbox,packet_id,body_b64,expires_ms,received_ms) VALUES (?,?,?,?,?)",
            (mailbox, packet, encoded, expires, now),
        )
        return 200, {"ok": True}

    def _pull(self, query: str, headers: dict, now: int) -> tuple[int, dict]:
        params = parse_qs(query, strict_parsing=True)
        if set(params) != {"mailbox"} or len(params["mailbox"]) != 1:
            return reject(400, "invalid_query")
        mailbox = params["mailbox"][0]
        authorization = headers.get("authorization", "")
        if not MAILBOX.fullmatch(mailbox) or not authorization.startswith("Bearer "):
            return reject(403, "unauthorized")
        read_token = authorization[7:]
        if not TOKEN.fullmatch(read_token) or not self._authorize(mailbox, read_token, "read", now):
            return reject(403, "unauthorized")
        rows = self.db.execute(
            "SELECT packet_id,body_b64,expires_ms,received_ms FROM packets "
            "WHERE mailbox=? AND expires_ms>? ORDER BY received_ms,packet_id LIMIT 32",
            (mailbox, now),
        ).fetchall()
        return 200, {"version": 1, "packets": [
            {"packetID": p, "body": payload, "expiresAt": expiration, "receivedAt": received}
            for p, payload, expiration, received in rows
        ]}

    def _ack(self, data: dict, now: int) -> tuple[int, dict]:
        mailbox = require_string(data, "mailbox", MAILBOX)
        read_token = require_string(data, "readToken", TOKEN)
        ids = data.get("packetIDs")
        if not isinstance(ids, list) or not (0 < len(ids) <= 32) or any(
            not isinstance(p, str) or not PACKET.fullmatch(p) for p in ids
        ):
            return reject(400, "invalid_packetIDs")
        if not self._authorize(mailbox, read_token, "read", now):
            return reject(403, "unauthorized")
        for packet_id in set(ids):
            live = self.db.execute(
                "SELECT body_b64, expires_ms FROM packets WHERE mailbox=? AND packet_id=?",
                (mailbox, packet_id),
            ).fetchone()
            if live is None:
                continue
            digest = hashlib.sha256(
                base64.b64decode(live[0], validate=True)
            ).hexdigest()
            self.db.execute(
                "INSERT OR IGNORE INTO acknowledged_packets"
                "(mailbox, packet_id, body_sha256, expires_ms) VALUES (?,?,?,?)",
                (mailbox, packet_id, digest, live[1]),
            )
            self.db.execute(
                "DELETE FROM packets WHERE mailbox=? AND packet_id=?",
                (mailbox, packet_id),
            )
        return 200, {"ok": True}


class Handler(BaseHTTPRequestHandler):
    store: RelayStore
    protocol_version = "HTTP/1.1"

    def _serve(self) -> None:
        length = self.headers.get("Content-Length", "0")
        if not length.isdecimal() or int(length) > MAX_BODY_BYTES:
            self.close_connection = True
            status, result = reject(413, "body_too_large")
        else:
            body = self.rfile.read(int(length))
            u = urlparse(self.path)
            status, result = self.store.request(self.command, u.path, u.query, dict(self.headers), body)
        data = json.dumps(result, separators=(",", ":")).encode("utf8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self) -> None:
        self._serve()

    def do_GET(self) -> None:
        self._serve()

    def log_message(self, format: str, *args) -> None:
        # Do not log sensitive mailbox IDs or auth query string by default.
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description="VeilLink localhost-only relay API reference")
    parser.add_argument("--db", default="relay-local.sqlite3")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8787, type=int)
    args = parser.parse_args()
    if args.host not in {"127.0.0.1", "::1", "localhost"}:
        parser.error("Reference server must bind to loopback only; use an independently audited production deployment")
    Handler.store = RelayStore(args.db)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        Handler.store.close()


if __name__ == "__main__":
    main()