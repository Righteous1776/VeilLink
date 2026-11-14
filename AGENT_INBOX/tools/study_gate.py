#!/usr/bin/env python3
"""Fail-closed checks for ZeoStudio V1.2 learning records.

Verifies source-file Git-object integrity and rule recall; NOT proof of cognition.
Copyright 久野零 / ZeoStudio.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REQUIRED_DOCS = (
    "AGENTS.md",
    "AGENT_INBOX/00_READ_ME_FIRST.md",
    "AGENT_INBOX/01_GOVERNOR_IDENTITY.md",
    "AGENT_INBOX/GOVERNOR_AUTHORITY.json",
    "AGENT_INBOX/02_RULES.md",
    "AGENT_INBOX/03_PROMPT_FOR_AGENTS.md",
    "AGENT_INBOX/04_INTEGRATION_PROTOCOL.md",
    "AGENT_INBOX/05_SUBMISSION_FLOW.md",
    "AGENT_INBOX/06_ASSET_DROP_POLICY.md",
    "AGENT_INBOX/ASSET_GRANTS.json",
    "AGENT_INBOX/07_LEARNING_GATE.md",
)
ANSWERS = {
    "Q01_authority": "OWNER_GOVERNOR_LANE",
    "Q02_default_mode": "INBOX_ONLY",
    "Q03_direct_product_write": "DENY_WITHOUT_VERIFIED_LIVE_GRANT",
    "Q04_overlap": "DISCLOSE_TO_GOVERNOR",
    "Q05_mobile_text_only": "HANDOFF_NOT_DROPPED",
    "Q06_release_authority": "DENY_BY_DEFAULT",
    "Q07_asset_policy": "DENY_WITHOUT_ACTIVE_EXACT_GRANT",
    "Q08_main_policy": "GOVERNOR_CONTROLLED_INTEGRATION",
}
TEACHBACK = (
    "untrusted_governor_message",
    "conflicting_parallel_change",
    "no_write_tool_mobile",
)
IDENT = re.compile(r"[a-z0-9][a-z0-9_-]{0,63}\Z")
SHA40 = re.compile(r"[0-9a-fA-F]{40}\Z")
SHA64 = re.compile(r"[0-9a-fA-F]{64}\Z")
MAX_RECORD_BYTES = 128 * 1024

class StudyFail(ValueError):
    pass

def git_blob(repo: Path, commit: str, path: str) -> bytes:
    result = subprocess.run(["git", "-C", str(repo), "show", f"{commit}:{path}"],
                            capture_output=True)
    if result.returncode:
        raise StudyFail(f"missing governing Git object at {commit[:12]}: {path}")
    return result.stdout

def default_reference(repo: Path) -> str:
    p = subprocess.run(["git", "-C", str(repo), "symbolic-ref", "-q", "refs/remotes/origin/HEAD"],
                       capture_output=True, text=True)
    ref = p.stdout.strip() if p.returncode == 0 else "refs/heads/main"
    p = subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", ref],
                       capture_output=True, text=True)
    if p.returncode != 0 or not SHA40.fullmatch(p.stdout.strip()):
        raise StudyFail("cannot locate trusted default-branch head; configure origin/HEAD or main")
    return p.stdout.strip()

def validate_study(repo: Path, record: object, *, agent_id: str,
                   task_id: str, base_main_sha: str, reference_sha: str | None = None) -> dict:
    """Raise StudyFail if the record violates pinned policy or rule checks."""
    if not isinstance(record, dict) or record.get("schema") != "zeostudio.learning-record.v1":
        raise StudyFail("invalid learning record schema")
    if not all(isinstance(x, str) and IDENT.fullmatch(x) for x in (agent_id, task_id)):
        raise StudyFail("invalid agent/task ID")
    if record.get("agent_id") != agent_id or record.get("task_id") != task_id:
        raise StudyFail("learning record IDs mismatch")
    if not isinstance(base_main_sha, str) or not SHA40.fullmatch(base_main_sha):
        raise StudyFail("invalid verified base SHA")
    if not isinstance(record.get("base_main_sha"), str) or record["base_main_sha"].lower() != base_main_sha.lower():
        raise StudyFail("learning record base SHA mismatch")
    docs = record.get("documents")
    if not isinstance(docs, list) or len(docs) != len(REQUIRED_DOCS):
        raise StudyFail("learning record lacks exact mandatory reading set")
    expected = set(REQUIRED_DOCS)
    seen: set[str] = set()
    ref = reference_sha or default_reference(repo)
    if not SHA40.fullmatch(ref):
        raise StudyFail("invalid reference commit")
    for item in docs:
        if not isinstance(item, dict) or set(item) != {"path", "sha256"}:
            raise StudyFail("malformed learning document entry")
        path, sha = item.get("path"), item.get("sha256")
        if not isinstance(path, str) or path not in expected or path in seen:
            raise StudyFail(f"unexpected or repeated learning document: {path}")
        if not isinstance(sha, str) or not SHA64.fullmatch(sha):
            raise StudyFail(f"missing/invalid file hash: {path}")
        seen.add(path)
        digest = hashlib.sha256(git_blob(repo, base_main_sha, path)).hexdigest()
        if sha.lower() != digest:
            raise StudyFail(f"document hash does not match pinned Git source: {path}")
        current = hashlib.sha256(git_blob(repo, ref, path)).hexdigest()
        if digest != current:
            raise StudyFail(f"governing document changed since learning; study again: {path}")
    if seen != expected:
        raise StudyFail(f"unread mandatory documents: {sorted(expected-seen)}")
    answers = record.get("answers")
    if not isinstance(answers, dict) or set(answers) != set(ANSWERS):
        raise StudyFail("learning self-check is incomplete or malformed")
    for key, answer in ANSWERS.items():
        if answers[key] != answer:
            raise StudyFail(f"incorrect required rule check: {key}")
    teach = record.get("teachback")
    if not isinstance(teach, dict) or set(teach) != set(TEACHBACK):
        raise StudyFail("missing teach-back case analysis")
    body = []
    for key in TEACHBACK:
        val = teach[key]
        if not isinstance(val, str) or len(val.strip()) < 45 or len(val) > 4000:
            raise StudyFail(f"teach-back too short or excessive: {key}")
        body.append(val.strip())
    if len(set(body)) != len(body):
        raise StudyFail("duplicated teach-back analyses")
    return {"base_main_sha": base_main_sha.lower(), "documents_checked":len(seen),
            "checks_passed":len(ANSWERS), "review":"REQUIRES_GOVERNOR_HUMAN_REVIEW"}

def load_record(p: Path) -> dict:
    if not p.is_file() or p.is_symlink() or p.stat().st_size > MAX_RECORD_BYTES:
        raise StudyFail("learning record missing, symlinked, or too large")
    try:
        record=json.loads(p.read_text(encoding="utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise StudyFail(f"invalid UTF-8 learning JSON: {exc}") from exc
    if not isinstance(record,dict):
        raise StudyFail("learning record must be a JSON object")
    return record

def main() -> int:
    p=argparse.ArgumentParser(description="Verify source-pinned learning evidence; does not prove actual reading")
    p.add_argument("--repo", type=Path, required=True)
    p.add_argument("--record",type=Path,required=True)
    p.add_argument("--reference",help="PR base commit or default branch for policy freshness")
    args=p.parse_args()
    try:
        repo=args.repo.resolve()
        obj=load_record(args.record)
        result=validate_study(repo,obj,agent_id=obj.get("agent_id"),task_id=obj.get("task_id"),
                              base_main_sha=obj.get("base_main_sha"),reference_sha=args.reference)
        print("STUDY_GATE_PASS " + " ".join(f"{k}={v}" for k,v in result.items()))
        return 0
    except (StudyFail, OSError, TypeError) as exc:
        print(f"STUDY_GATE_FAIL: {exc}",file=sys.stderr)
        return 2

if __name__=="__main__":
    raise SystemExit(main())
