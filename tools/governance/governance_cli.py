#!/usr/bin/env python3
"""Zeo Agent Foundation — durable Session and governance checks.

Author/scheme: 久野零 (ZeoStudio). Local checks, not remote authorization.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
import os
import pathlib
import re
import subprocess
import sys
import uuid


def repo_root() -> pathlib.Path:
    env = os.environ.get("ZEO_REPO_ROOT")
    if env:
        return pathlib.Path(env).expanduser().resolve()
    p = pathlib.Path(__file__).resolve()
    for ancestor in p.parents:
        if (ancestor / "governance" / "CONSTITUTION_SEAL.json").exists():
            return ancestor
    return pathlib.Path.cwd().resolve()


ROOT = repo_root()
GOV = ROOT / "governance"
SESSIONS = ROOT / "agent_sessions"


def error(message: str, code: int = 2):
    print(message, file=sys.stderr)
    raise SystemExit(code)


def safe_id(s: str):
    if not isinstance(s, str) or not re.fullmatch(r"[a-zA-Z0-9._-]{1,120}", s):
        error(f"INVALID_IDENTIFIER: {s!r}")
    return s


def load(path: pathlib.Path):
    if not path.is_file():
        error(f"MISSING_FILE: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: pathlib.Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def git_rev(ref: str):
    r = subprocess.run(["git", "rev-parse", "--verify", ref], cwd=ROOT, text=True, capture_output=True, check=False)
    return r.stdout.strip() if r.returncode == 0 else None


def iso():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def session_path(task):
    return SESSIONS / safe_id(task) / "SESSION_STATE.json"


def must_read(profile: str):
    seal = load(GOV / "CONSTITUTION_SEAL.json")
    required = load(GOV / "MANDATORY_READ_SET.json")
    if required["governance_epoch"] != seal["governance_epoch"] or required["constitution_version"] != seal["constitution_version"]:
        error("SEAL_MANDATORY_SET_MISMATCH")
    paths = list(required.get("common", [])) + list(required.get("role_sets", {}).get(profile, []))
    if (ROOT / "AGENT_EXCHANGE" / "README.md").is_file():
        paths += required.get("optional_if_exchange_installed", [])
    paths = list(dict.fromkeys(paths))
    for p in paths:
        # Only allow explicitly relative files within root.
        x = (ROOT / p).resolve()
        if not x.is_relative_to(ROOT) or not x.is_file():
            error(f"MANDATORY_MISSING_OR_UNSAFE: {p}")
    return seal, paths


def cmd_init(args):
    safe_id(args.task_id)
    safe_id(args.profile)
    safe_id(args.lane)
    out = session_path(args.task_id)
    if out.exists():
        error("SESSION_ALREADY_EXISTS: use resume, do not reset")
    seal = load(GOV / "CONSTITUTION_SEAL.json")
    template = load(GOV / "templates" / "SESSION_STATE.template.json")
    template.update(task_id=args.task_id, session_id=args.session_id or "SESSION-" + uuid.uuid4().hex[:10].upper(),
                    profile=args.profile, lane=args.lane, branch=args.branch,
                    workspace=f"workspaces/{args.lane}/{args.task_id}/",
                    governance_epoch=seal["governance_epoch"], constitution_version=seal["constitution_version"],
                    governance_source_sha=git_rev("main"), status="READ_PENDING",
                    last_verified_commit=git_rev("HEAD"),
                    handoff_path=f"agent_sessions/{args.task_id}/HANDOFF.md",
                    updated_at=iso())
    template["read_attestation"] = {"status": "PENDING", "acknowledged_at": None, "files_read": [], "mandatory_read_complete": False}
    template["next_unique_task_zh_cn"] = "完成 Mandatory Read，并记录真实 ACK。"
    save(out, template)
    handoff = out.parent / "HANDOFF.md"
    handoff.write_text(f"# HANDOFF — {args.task_id}\n\n- 状态：READ_PENDING\n- Branch：{args.branch}\n- Epoch：{seal['governance_epoch']}\n- Session：{template['session_id']}\n- Next：完成 Mandatory Read 和真实 ACK\n", encoding="utf-8")
    print(f"CREATED={out.relative_to(ROOT)}\nREAD_ATTESTATION=PENDING")
    return 0


def cmd_mandatory(args):
    state = load(session_path(args.task_id))
    seal, paths = must_read(state["profile"])
    print(f"CURRENT_EPOCH={seal['governance_epoch']}\nVERSION={seal['constitution_version']}\nREQUIRED_FILES={len(paths)}")
    for p in paths:
        print(p)
    print("ACK MUST REFLECT ACTUAL READING; listing paths does not acknowledge reading.")
    return 0


def cmd_ack(args):
    p = session_path(args.task_id)
    state = load(p)
    seal, paths = must_read(state["profile"])
    provided = set(args.file_read or [])
    missing = [x for x in paths if x not in provided]
    if missing:
        error("ACK_INCOMPLETE_MANDATORY_READ: " + ", ".join(missing))
    if not args.confirm_actually_read:
        error("ACK_REQUIRES_EXPLICIT_CONFIRMATION")
    state["governance_epoch"] = seal["governance_epoch"]
    state["constitution_version"] = seal["constitution_version"]
    state["governance_source_sha"] = git_rev("main")
    state["read_attestation"] = {"status": "ACKNOWLEDGED", "acknowledged_at": iso(),
                                 "files_read": sorted(provided), "mandatory_read_complete": True}
    if state.get("status") in ("READ_PENDING", "STALE_GOVERNANCE"):
        state["status"] = "WORKING"
    state["updated_at"] = iso()
    save(p, state)
    print("ACKNOWLEDGED: file list asserted by agent, not machine-verified semantic reading")
    return 0


def check_state(task_id):
    state = load(session_path(task_id))
    seal, paths = must_read(state["profile"])
    problems = []
    if state.get("task_id") != task_id:
        problems.append("TASK_ID_MISMATCH")
    if state.get("governance_epoch") != seal["governance_epoch"] or state.get("constitution_version") != seal["constitution_version"]:
        problems.append("STALE_GOVERNANCE")
    attest = state.get("read_attestation") or {}
    if attest.get("status") != "ACKNOWLEDGED" or attest.get("mandatory_read_complete") is not True:
        problems.append("MANDATORY_READ_NOT_ACKNOWLEDGED")
    missing = set(paths) - set(attest.get("files_read") or [])
    if missing:
        problems.append("MANDATORY_READ_FILES_MISSING:" + ",".join(sorted(missing)))
    for k in ("session_id", "branch", "workspace", "output_contract_id", "next_unique_task_zh_cn"):
        if not state.get(k):
            problems.append("MISSING_" + k.upper())
    if state.get("status") == "COMPLETE":
        if not state.get("completed") or not state.get("last_verified_commit") or not state.get("takeover_ready"):
            problems.append("COMPLETE_NOT_RECOVERABLE")
        if (ROOT / "AGENT_EXCHANGE" / "README.md").exists() and not (state.get("agent_exchange") or {}).get("completion_reported"):
            problems.append("COMPLETE_WITHOUT_WORK_REPORT")
    return state, problems


def cmd_check(args):
    _, problems = check_state(args.task_id)
    for p in problems:
        print("FAIL: " + p)
    print(f"ISSUES={len(problems)}")
    return 1 if problems else 0


def cmd_handoff(args):
    state = load(session_path(args.task_id))
    path = ROOT / state["handoff_path"]
    fmt = lambda xs: "\n".join("- " + str(s) for s in xs) or "- 无"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"""# HANDOFF — {state['task_id']}

## 身份与版本
- Session：{state['session_id']}
- Profile/Lane：{state['profile']} / {state['lane']}
- Branch：{state['branch']}
- Epoch：{state['governance_epoch']}
- Source SHA：{state.get('governance_source_sha')}
- Last verified commit：{state.get('last_verified_commit')}
- Output contract：{state.get('output_contract_id')} / {state.get('active_output_mode')}

## 当前状态
- {state.get('status')}

## 已完成
{fmt(state.get('completed', []))}

## 产物
{fmt(state.get('active_files', []))}

## Durable decisions
{fmt(state.get('durable_decisions', []))}

## Must not change
{fmt(state.get('must_not_change', []))}

## 未解决
{fmt(state.get('unresolved', []))}

## Locks
- Held：{state.get('locks', {}).get('held', [])}
- Released：{state.get('locks', {}).get('released', [])}

## Agent Exchange
- {state.get('agent_exchange', {})}

## 下一步唯一任务
{state.get('next_unique_task_zh_cn', '')}
""", encoding="utf-8")
    print(f"HANDOFF={path.relative_to(ROOT)}")
    return 0


def cmd_status(args):
    state, problems = check_state(args.task_id)
    print(json.dumps({"task_id": args.task_id, "status": state.get("status"),
                      "next_unique_task_zh_cn": state.get("next_unique_task_zh_cn"),
                      "issues": problems}, ensure_ascii=False, indent=2))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Zeo Agent governance Session CLI — local only")
    sub = ap.add_subparsers(dest="cmd", required=True)
    init = sub.add_parser("init-task")
    for name in ("task-id", "profile", "lane", "branch"):
        init.add_argument("--" + name, required=True)
    init.add_argument("--session-id")
    init.set_defaults(func=cmd_init)
    for name, callback in [("mandatory", cmd_mandatory), ("check", cmd_check), ("handoff", cmd_handoff), ("status", cmd_status)]:
        p = sub.add_parser(name)
        p.add_argument("--task-id", required=True)
        p.set_defaults(func=callback)
    ack = sub.add_parser("ack")
    ack.add_argument("--task-id", required=True)
    ack.add_argument("--file-read", action="append", required=True)
    ack.add_argument("--confirm-actually-read", action="store_true")
    ack.set_defaults(func=cmd_ack)
    args = ap.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
