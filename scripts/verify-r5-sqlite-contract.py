#!/usr/bin/env python3
"""Read-only R5 SQLite schema preflight. Not a replacement for XCTest or real backups."""
import pathlib
import re
import sqlite3
import sys

SOURCE = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                      else "VeilLink/Storage/DatabaseStore.swift")

def migration_sql(source, name):
    pattern = (r"private\s+func\s+" + re.escape(name)
               + r"\s*\(\s*\)\s*throws\s*\{[\s\S]*?"
               + r'try\s+transaction\s*\(\s*"""([\s\S]*?)"""\s*\)')
    match = re.search(pattern, source)
    if not match:
        raise AssertionError("Missing migration: " + name)
    sql = match.group(1)
    if r"\(" in sql:
        raise AssertionError("Unexpected SQL interpolation in " + name)
    return sql

def apply(db, sql):
    try:
        db.executescript("BEGIN IMMEDIATE;\n" + sql + "\nCOMMIT;")
    except Exception:
        db.rollback()
        raise

def verify(source):
    v9 = migration_sql(source, "migratePeerCapabilitiesV9")
    v10 = migration_sql(source, "migrateDurableControlOutboxV10")
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript("""
        CREATE TABLE schema_migrations(version INTEGER PRIMARY KEY, applied_at REAL NOT NULL);
        CREATE TABLE contacts(local_identity_id TEXT NOT NULL, identity_id TEXT NOT NULL,
            public_key BLOB NOT NULL, PRIMARY KEY(local_identity_id,identity_id));
        CREATE TABLE messages(id TEXT PRIMARY KEY, body BLOB NOT NULL);
        INSERT INTO schema_migrations VALUES(8, 1);
        INSERT INTO messages VALUES('legacy', X'010203');
        INSERT INTO contacts VALUES('A', 'one', X'AA');
        INSERT INTO contacts VALUES('A', 'two', X'BB');
        INSERT INTO contacts VALUES('B', 'one', X'CC');
    """)
    for migration in (v9, v10, v9, v10):
        apply(db, migration)
    tables = {row[0] for row in db.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table'")}
    required = {"peer_capabilities", "control_event_inbox",
                "control_outbound_events", "control_outbound_targets"}
    assert required <= tables, required - tables
    assert [r[0] for r in db.execute("SELECT version FROM schema_migrations ORDER BY version")] == [8, 9, 10]
    assert db.execute("SELECT body FROM messages WHERE id='legacy'").fetchone()[0] == bytes((1, 2, 3))
    for local, peer in (("A", "one"), ("B", "one")):
        db.execute("""INSERT INTO peer_capabilities(
            local_identity_id,peer_identity_id,public_key_sha256,
            capability_schema_version,feature_bits,observed_at)
            VALUES(?,?,?,1,7,123)""", (local, peer, bytes(32)))
    assert db.execute("SELECT COUNT(*) FROM peer_capabilities").fetchone()[0] == 2
    db.execute("""INSERT INTO control_outbound_events(
        local_identity_id,event_id,payload_ciphertext,created_at,expires_at)
        VALUES('A','event',X'AABB',1,200)""")
    for peer in ("one", "two"):
        db.execute("""INSERT INTO control_outbound_targets(
            local_identity_id,event_id,peer_identity_id,next_attempt_at,attempts)
            VALUES('A','event',?,1,0)""", (peer,))
    db.commit()
    assert db.execute("SELECT COUNT(*) FROM control_outbound_targets").fetchone()[0] == 2
    db.execute("DELETE FROM contacts WHERE local_identity_id='A' AND identity_id='one'")
    db.commit()
    assert db.execute("SELECT COUNT(*) FROM control_outbound_targets").fetchone()[0] == 1
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
    assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    print("R5_SQLITE_STRUCTURE_PREFLIGHT_PASS (synthetic fixture only)")

if __name__ == "__main__":
    verify(SOURCE.read_text(encoding="utf-8"))
