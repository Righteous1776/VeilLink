#!/usr/bin/env python3
"""Zeo Agent Exchange Inbox CLI — 久野零 (ZeoStudio) scheme.

Local-only, standard-library, no background daemon and no remote delivery claims.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
import os
import pathlib
import re
import sys
import uuid

TYPES = {"INFO", "WORK_REPORT", "REQUIRED_READ", "REQUIRED_RESPONSE", "REPLY", "TASK_REQUEST", "TASK_ASSIGNMENT", "BLOCKER", "HANDOFF", "DECISION", "OWNER_DECISION_REQUIRED"}
DELIVERIES = {"INFO", "REQUIRED_READ", "REQUIRED_RESPONSE"}
PRIORITIES = {"P0", "P1", "P2", "P3"}
TARGET = re.compile(r"^(ALL|GOVERNOR|CHIEF_STRATEGIST|(?:GOVERNOR|TASK|PROFILE|LANE):[A-Za-z0-9._-]+)$")
MAX_MESSAGE_BYTES = 2_000_000


def root_dir() -> pathlib.Path:
    if os.getenv("ZEO_REPO_ROOT"):
        return pathlib.Path(os.environ["ZEO_REPO_ROOT"]).expanduser().resolve()
    here = pathlib.Path(__file__).resolve()
    for base in [here.parent, *here.parents]:
        if (base / "AGENT_EXCHANGE").is_dir() and (base / "governance").is_dir():
            return base
    return pathlib.Path.cwd().resolve()


ROOT = root_dir()
EXCHANGE = ROOT / "AGENT_EXCHANGE"
MESSAGES = EXCHANGE / "messages"
RECEIPTS = EXCHANGE / "receipts"
SEAL = ROOT / "governance" / "CONSTITUTION_SEAL.json"


def die(message: str, code: int = 2) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def clean(value: str) -> str:
    if not value or not re.fullmatch(r"[A-Za-z0-9._-]{1,120}", value):
        die("INVALID_IDENTIFIER: use 1..120 ASCII letters/digits/_/./-")
    return value


def read_json(path: pathlib.Path) -> dict:
    if path.stat().st_size > MAX_MESSAGE_BYTES:
        raise ValueError("JSON_FILE_TOO_LARGE")
    x = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(x, dict):
        raise ValueError("OBJECT_REQUIRED")
    return x


def atomic_new_json(path: pathlib.Path, item: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(item, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    if len(data) > MAX_MESSAGE_BYTES:
        die("MESSAGE_TOO_LARGE")
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        die("MESSAGE_ALREADY_EXISTS")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def atomic_replace_json(path: pathlib.Path, item: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        atomic_new_json(tmp, item)
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def current_governance() -> tuple[int, str]:
    if not SEAL.is_file():
        die("MISSING_CONSTITUTION_SEAL: install governance skill or create approved seal")
    seal = read_json(SEAL)
    return int(seal["governance_epoch"]), str(seal["constitution_version"])


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def iter_messages() -> list[pathlib.Path]:
    return sorted(MESSAGES.glob("*/*/*/MSG-*.json")) if MESSAGES.exists() else []


def get_message(message_id: str) -> dict | None:
    clean(message_id)
    for path in iter_messages():
        if path.stem == message_id:
            msg = read_json(path)
            if msg.get("message_id") == message_id:
                return msg
    return None


def matches_target(t: str, args: argparse.Namespace) -> bool:
    if t == "ALL" or t == f"TASK:{args.task_id}" or t == f"PROFILE:{args.profile}" or t == f"LANE:{args.lane}":
        return True
    if t == "GOVERNOR" and args.profile in {"GOVERNOR", "SYSTEM_GOVERNOR", "SUPREME_GOVERNOR", "INTEGRATION_GOVERNOR"}:
        return True
    if t.startswith("GOVERNOR:") and args.profile in {"GOVERNOR", "SYSTEM_GOVERNOR", "SUPREME_GOVERNOR", "INTEGRATION_GOVERNOR"}:
        return bool(args.governor_identity and t == f"GOVERNOR:{args.governor_identity}")
    if t == "CHIEF_STRATEGIST" and args.profile == "SYSTEM_CHIEF_STRATEGIST":
        return True
    return False


def addressed(msg: dict, args: argparse.Namespace) -> bool:
    return any(matches_target(t, args) for t in msg.get("targets", []))


def rp(mid: str, task: str) -> pathlib.Path:
    return RECEIPTS / clean(mid) / (clean(task) + ".json")


def valid_receipt(msg: dict, task: str, rec: dict) -> bool:
    status = rec.get("status")
    if rec.get("message_id") != msg["message_id"] or rec.get("recipient_task_id") != task:
        return False
    if status == "NOT_APPLICABLE":
        # A required response cannot be closed merely by saying "not applicable".
        return (msg["delivery"] == "REQUIRED_READ" and
                bool(str(rec.get("note_zh_cn") or "").strip()))
    if msg["delivery"] == "REQUIRED_READ":
        return status in {"READ", "RESPONDED"}
    if msg["delivery"] != "REQUIRED_RESPONSE":
        return True
    if status != "RESPONDED":
        return False
    rid = rec.get("response_message_id")
    reply = get_message(rid) if isinstance(rid, str) else None
    return bool(reply and reply.get("type") == "REPLY" and reply.get("in_reply_to") == msg["message_id"] and (reply.get("sender") or {}).get("task_id") == task)


def ensure_sender(args):
    for k in ("task_id", "session_id", "profile", "lane"):
        clean(getattr(args, k))
    if args.governor_identity:
        clean(args.governor_identity)


def governor_authorized(args) -> bool:
    if args.profile not in {"GOVERNOR", "SYSTEM_GOVERNOR", "SUPREME_GOVERNOR", "INTEGRATION_GOVERNOR"}:
        return False
    registry = ROOT / "governance" / "GOVERNOR_REGISTRY.json"
    if not registry.is_file():
        return False
    for g in read_json(registry).get("governors", []):
        if (g.get("task_id") == args.task_id and g.get("identity") == args.governor_identity
            and g.get("profile") == args.profile and g.get("status") == "ACTIVE"
            and ("TASK_ASSIGNMENT" in g.get("capabilities", []))):
            return True
    return False


def write_message(args, kind: str, reply_id: str | None = None) -> tuple[str, pathlib.Path]:
    ensure_sender(args)
    if kind not in TYPES:
        die("INVALID_SCHEMA: unsupported type")
    targets = list(dict.fromkeys(args.target or ["ALL"]))
    delivery = args.delivery
    if kind == "TASK_REQUEST":
        targets, delivery = args.target or ["GOVERNOR"], "REQUIRED_RESPONSE"
    if kind == "TASK_ASSIGNMENT":
        if not args.target:
            die("TASK_ASSIGNMENT_REQUIRES_EXPLICIT_TARGET")
        if not governor_authorized(args):
            die("TASK_ASSIGNMENT_REQUIRES_REGISTERED_GOVERNOR")
        delivery = "REQUIRED_READ" if delivery == "INFO" else delivery
    if kind == "WORK_REPORT" and delivery == "INFO" and targets != ["ALL"]:
        delivery = "REQUIRED_READ"
    if kind == "REQUIRED_READ":
        delivery = "REQUIRED_READ"
    if kind == "REQUIRED_RESPONSE":
        delivery = "REQUIRED_RESPONSE"
    if kind == "REPLY":
        origin = get_message(reply_id or "") if reply_id else None
        if not origin:
            die("MESSAGE_NOT_FOUND")
        if not addressed(origin, args):
            die("MESSAGE_NOT_ADDRESSED_TO_RECIPIENT")
        targets = ["TASK:" + origin["sender"]["task_id"]]
        delivery = "INFO"
    if not targets or any(not TARGET.fullmatch(t) for t in targets):
        die("INVALID_TARGET")
    epoch, version = current_governance()
    t = dt.datetime.now(dt.timezone.utc)
    mid = f"MSG-{t:%Y%m%d-%H%M%S}-{clean(args.task_id)}-{uuid.uuid4().hex[:8].upper()}"
    report = None
    if kind == "WORK_REPORT":
        report = {
            "completed": args.completed or [], "artifacts": args.artifact or [],
            "shared_state_changed": args.shared_state or [], "not_done": args.not_done or [],
            "downstream_read": args.downstream_read or [], "notify_targets": targets,
            "next_recommendation": args.next_recommendation or ""
        }
    message = {
        "schema_version": "1.0", "governance_epoch": epoch, "constitution_version": version,
        "message_id": mid, "created_at": t.isoformat(timespec="seconds"),
        "sender": {"task_id": args.task_id, "session_id": args.session_id, "profile": args.profile,
                   "lane": args.lane, "governor_identity": args.governor_identity},
        "type": kind, "delivery": delivery, "priority": args.priority, "targets": targets,
        "subject_zh_cn": args.subject, "body_zh_cn": args.body, "work_report": report,
        "references": {"branch": args.branch, "commit": args.commit, "files": args.file or [],
                       "task_state": f"agent_sessions/{args.task_id}/SESSION_STATE.json"},
        "in_reply_to": reply_id, "response_required": delivery == "REQUIRED_RESPONSE",
        "due_before_next_substantive_work": delivery != "INFO" and args.priority in {"P0", "P1"},
        "task_request": {"requested_scope": args.requested_scope or "", "blocker": args.blocker or "",
                         "safe_parallel_work_available": not args.no_safe_parallel_work} if kind == "TASK_REQUEST" else None,
        "task_assignment": {"assigned_task_id": args.assigned_task_id or "", "assigned_profile": args.assigned_profile or "",
                            "assigned_lane": args.assigned_lane or "", "authority_required": args.authority_required or "",
                            "start_condition": args.start_condition or "", "dependencies": args.dependency or []} if kind == "TASK_ASSIGNMENT" else None,
        "owner_decision_required": {"decision_scope": args.decision_scope or "", "options": args.option or [],
                                    "impact_if_unresolved": args.impact_if_unresolved or "", "safe_default": "HOLD"} if kind == "OWNER_DECISION_REQUIRED" else None,
    }
    p = MESSAGES / f"{t:%Y}" / f"{t:%m}" / f"{t:%d}" / (mid + ".json")
    atomic_new_json(p, message)
    print(f"MESSAGE_ID={mid}\nPATH={p.relative_to(ROOT)}")
    return mid, p


def cmd_send(args):
    write_message(args, args.type)
    return 0


def cmd_report(args):
    write_message(args, "WORK_REPORT")
    return 0


def cmd_reply(args):
    write_message(args, "REPLY", args.in_reply_to)
    return 0


def cmd_read(args):
    msg = get_message(args.message_id)
    if msg is None:
        die("MESSAGE_NOT_FOUND")
    print(json.dumps(msg, ensure_ascii=False, indent=2))
    return 0


def cmd_scan(args):
    clean(args.task_id)
    pending, info = [], []
    for p in iter_messages():
        try:
            msg = read_json(p)
        except (ValueError, OSError):
            die(f"INVALID_SCHEMA: {p}")
        if (msg.get("sender") or {}).get("task_id") == args.task_id or not addressed(msg, args):
            continue
        if msg.get("delivery") not in DELIVERIES:
            die(f"INVALID_SCHEMA: {p}")
        if msg["delivery"] == "INFO":
            info.append(msg)
            continue
        recfile = rp(msg["message_id"], args.task_id)
        if not recfile.is_file() or not valid_receipt(msg, args.task_id, read_json(recfile)):
            pending.append(msg)
    blocking = [m for m in pending if m.get("priority") in {"P0", "P1"}]
    if args.json:
        print(json.dumps({"pending_required": pending, "info_count": len(info), "blocking_count": len(blocking)}, ensure_ascii=False, indent=2))
    else:
        for m in pending:
            print(json.dumps({k: m.get(k) for k in ("message_id", "priority", "delivery", "subject_zh_cn", "due_before_next_substantive_work")}, ensure_ascii=False))
        if args.show_info:
            for m in info:
                print(f"INFO {m['message_id']}: {m['subject_zh_cn']}")
        print(f"PENDING_REQUIRED={len(pending)}\nINFO_MATCHED={len(info)}\nBLOCKING={len(blocking)}")
    return 3 if blocking else 0


def cmd_receipt(args):
    ensure_sender(args)
    msg = get_message(args.message_id)
    if not msg:
        die("MESSAGE_NOT_FOUND")
    if not addressed(msg, args):
        die("MESSAGE_NOT_ADDRESSED_TO_RECIPIENT")
    if args.status == "NOT_APPLICABLE" and not args.note.strip():
        die("NOT_APPLICABLE_REQUIRES_REASON")
    if args.status == "RESPONDED":
        if not args.response_message_id:
            die("REPLY_REQUIRED")
        ref = get_message(args.response_message_id)
        if not ref or ref.get("type") != "REPLY" or ref.get("in_reply_to") != msg["message_id"] or (ref.get("sender") or {}).get("task_id") != args.task_id:
            die("BAD_RESPONSE_REFERENCE")
    if args.status == "READ" and msg["delivery"] == "REQUIRED_RESPONSE":
        # intermediate acknowledgment permitted but does not satisfy REQUIRED_RESPONSE
        pass
    file = rp(args.message_id, args.task_id)
    if file.is_file():
        old = read_json(file)
        if old.get("status") == "RESPONDED" and args.status != "RESPONDED":
            die("RECEIPT_STATUS_REGRESSION")
    epoch, version = current_governance()
    data = {"schema_version": "1.0", "governance_epoch": epoch, "constitution_version": version,
            "message_id": args.message_id, "recipient_task_id": args.task_id,
            "recipient_session_id": args.session_id, "recipient_profile": args.profile,
            "recipient_lane": args.lane, "recipient_governor_identity": args.governor_identity,
            "status": args.status, "read_at": now(),
            "response_message_id": args.response_message_id, "note_zh_cn": args.note}
    atomic_replace_json(file, data)
    print(f"RECEIPT={file.relative_to(ROOT)}")
    return 0


def cmd_digest(_args):
    required, info = [], 0
    for p in iter_messages():
        m = read_json(p)
        if m.get("delivery") in {"REQUIRED_READ", "REQUIRED_RESPONSE"}:
            required.append(m)
        else:
            info += 1
    lines = ["# CURRENT_DIGEST — 工作群导航", "", "此摘要不是已读证明，也不是授权文件；必须按 Task 单独 scan。", "",
             f"- 消息总数：{len(required)+info}", f"- Required 原始消息数：{len(required)}", f"- 普通消息数：{info}", "",
             "## 最新 Required 消息（不判断全员完成）", ""]
    for m in required[-30:]:
        lines.append(f"- `{m['message_id']}` / {m['delivery']} / {','.join(m['targets'])} — {m['subject_zh_cn']}")
    if not required:
        lines.append("- 无")
    lines.append("")
    out = EXCHANGE / "CURRENT_DIGEST.md"
    # digest is a derived file and may be rewritten, but not a source of read status
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(out.relative_to(ROOT))
    return 0


def cmd_validate(_args):
    errors = []
    ids = set()
    for p in iter_messages():
        try:
            m = read_json(p)
            mid = m["message_id"]
            if not re.fullmatch(r"MSG-\d{8}-\d{6}-[A-Za-z0-9._-]+-[A-F0-9]{6,12}", mid):
                errors.append(f"INVALID_ID {p}")
            if mid != p.stem or mid in ids:
                errors.append(f"ID_MISMATCH_OR_DUPLICATE {p}")
            ids.add(mid)
            if m.get("schema_version") != "1.0" or m.get("delivery") not in DELIVERIES or m.get("type") not in TYPES or m.get("priority") not in PRIORITIES:
                errors.append(f"INVALID_SCHEMA {p}")
            if not m.get("targets") or any(not TARGET.fullmatch(t) for t in m["targets"]):
                errors.append(f"INVALID_TARGET {p}")
            if m.get("type") == "REPLY" and not m.get("in_reply_to"):
                errors.append(f"ORPHAN_REPLY {p}")
        except (OSError, ValueError, KeyError, TypeError) as e:
            errors.append(f"BROKEN_MESSAGE {p}: {e}")
    for f in RECEIPTS.glob("*/*.json") if RECEIPTS.exists() else []:
        try:
            r = read_json(f)
            m = get_message(r["message_id"])
            if not m:
                errors.append(f"RECEIPT_WITHOUT_MESSAGE {f}")
            elif f.parent.name != r["message_id"] or f.stem != r["recipient_task_id"]:
                errors.append(f"BAD_RECEIPT_PATH {f}")
            elif r["status"] == "RESPONDED" and not valid_receipt(m, r["recipient_task_id"], r):
                errors.append(f"BAD_RESPONSE_REFERENCE {f}")
        except (OSError, ValueError, KeyError) as e:
            errors.append(f"BROKEN_RECEIPT {f}: {e}")
    for e in errors:
        print(e)
    print(f"VALIDATION_ERRORS={len(errors)}")
    return 1 if errors else 0


def sender_args(parser: argparse.ArgumentParser):
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--lane", required=True)
    parser.add_argument("--governor-identity")
    parser.add_argument("--branch", default="")
    parser.add_argument("--commit", default="")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--body", required=True)
    parser.add_argument("--target", action="append")
    parser.add_argument("--priority", choices=sorted(PRIORITIES), default="P2")
    parser.add_argument("--delivery", choices=sorted(DELIVERIES), default="INFO")
    parser.add_argument("--file", action="append")
    parser.add_argument("--requested-scope", default="")
    parser.add_argument("--blocker", default="")
    parser.add_argument("--no-safe-parallel-work", action="store_true")
    parser.add_argument("--assigned-task-id")
    parser.add_argument("--assigned-profile")
    parser.add_argument("--assigned-lane")
    parser.add_argument("--authority-required")
    parser.add_argument("--start-condition")
    parser.add_argument("--dependency", action="append")
    parser.add_argument("--decision-scope")
    parser.add_argument("--option", action="append")
    parser.add_argument("--impact-if-unresolved")
    parser.add_argument("--completed", action="append")
    parser.add_argument("--artifact", action="append")
    parser.add_argument("--shared-state", action="append")
    parser.add_argument("--not-done", action="append")
    parser.add_argument("--downstream-read", action="append")
    parser.add_argument("--next-recommendation")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Zeo Agent Exchange / Inbox: local durable messages")
    sub = parser.add_subparsers(dest="cmd", required=True)
    scan = sub.add_parser("scan")
    for key in ("task-id", "profile", "lane"):
        scan.add_argument("--" + key, required=True)
    scan.add_argument("--governor-identity")
    scan.add_argument("--json", action="store_true")
    scan.add_argument("--show-info", action="store_true")
    scan.set_defaults(func=cmd_scan)
    send = sub.add_parser("send")
    sender_args(send)
    send.add_argument("--type", choices=sorted(TYPES - {"REPLY", "WORK_REPORT"}), default="INFO")
    send.set_defaults(func=cmd_send)
    report = sub.add_parser("report")
    sender_args(report)
    report.set_defaults(func=cmd_report)
    reply = sub.add_parser("reply")
    sender_args(reply)
    reply.add_argument("--in-reply-to", required=True)
    reply.set_defaults(func=cmd_reply)
    receipt = sub.add_parser("receipt")
    for key in ("message-id", "task-id", "session-id", "profile", "lane"):
        receipt.add_argument("--" + key, required=True)
    receipt.add_argument("--governor-identity")
    receipt.add_argument("--status", choices=["READ", "RESPONDED", "NOT_APPLICABLE", "BLOCKED"], required=True)
    receipt.add_argument("--response-message-id")
    receipt.add_argument("--note", default="")
    receipt.set_defaults(func=cmd_receipt)
    read = sub.add_parser("read")
    read.add_argument("--message-id", required=True)
    read.set_defaults(func=cmd_read)
    sub.add_parser("digest").set_defaults(func=cmd_digest)
    sub.add_parser("validate").set_defaults(func=cmd_validate)
    a = parser.parse_args(argv)
    return int(a.func(a))


if __name__ == "__main__":
    raise SystemExit(main())
