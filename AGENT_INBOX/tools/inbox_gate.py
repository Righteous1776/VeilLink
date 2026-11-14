#!/usr/bin/env python3
"""Portable, read-only Agent Inbox V1 structural gate. Copyright 久野零 / ZeoStudio."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from typing import Any
from study_gate import validate_study, load_record, StudyFail, default_reference

REQUIRED = ("MANIFEST.md", "PROPOSAL.md", "PATCH.diff", "TEST_PLAN.md", "RISKS.md", "STUDY_RECORD.json")
MAX_TEXT_BYTES = 2 * 1024 * 1024
SHA40 = re.compile(r"^[a-fA-F0-9]{40}$")
SHA64 = re.compile(r"^[a-fA-F0-9]{64}$")
IDENT = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
DROP_BRANCH = re.compile(r"^agent-drop/([a-z0-9][a-z0-9_-]{0,63})/([a-z0-9][a-z0-9_-]{0,63})$")
ADMIN_BRANCH = re.compile(r"^admin/[a-zA-Z0-9][a-zA-Z0-9._/-]{0,120}$")
ARCHIVE_SUFFIXES = {".zip", ".7z", ".rar", ".tar", ".gz", ".bz2", ".xz", ".tgz", ".zst"}
SECRET_SUFFIXES = {".p12", ".pfx", ".pem", ".key", ".mobileprovision", ".keystore"}
RESERVED_IDS = {"_template", "admin", "tools", "readme.md"}

class GateFail(RuntimeError):
    pass

def fail(message: str) -> None:
    raise GateFail(message)

def git(repo: Path, *args: str) -> str:
    cp = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if cp.returncode:
        fail(f"git {' '.join(args[:2])} failed: {cp.stderr.strip() or cp.stdout.strip()}")
    return cp.stdout.strip()

def ensure_inside(root: Path, path: Path) -> None:
    try:
        path.resolve(strict=False).relative_to(root.resolve())
    except ValueError:
        fail(f"path escaped checkout: {path}")

def checked_relative(raw: str) -> PurePosixPath:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\x00" in raw:
        fail(f"invalid path string: {raw!r}")
    p = PurePosixPath(raw)
    if p.is_absolute() or any(x in ("..", ".", "") for x in raw.split("/")):
        fail(f"path traversal or invalid path: {raw!r}")
    if ":" in p.parts[0]:
        fail(f"drive-prefixed path rejected: {raw!r}")
    return p

def parse_manifest(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    found: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"^\s*(?:-\s*)?([a-z][a-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if m:
            k, v = m.groups()
            found[k] = v.strip().strip("`\"'")
    for key in ("agent_id", "task_id", "status", "base_main_sha", "created_at", "scope", "proposed_files", "protected_surfaces", "dependencies", "known_overlaps"):
        if not found.get(key):
            fail(f"MANIFEST.md missing nonempty {key}")
    if found["status"] != "DROPPED":
        fail("new submission MANIFEST.md status must be DROPPED")
    if not SHA40.fullmatch(found["base_main_sha"]):
        fail("base_main_sha must be exactly 40 hex digits")
    if not IDENT.fullmatch(found["agent_id"]) or not IDENT.fullmatch(found["task_id"]):
        fail("agent_id/task_id must be stable filesystem-safe identifiers")
    return found

def check_patch(text: str) -> None:
    if text.lstrip().startswith("NO_PATCH:"):
        if len(text.split("NO_PATCH:", 1)[-1].strip()) < 12:
            fail("NO_PATCH requires a substantive explanation")
        return
    if "diff --git " not in text or "--- " not in text or "+++ " not in text:
        fail("PATCH.diff must be a unified Git diff or begin NO_PATCH: with rationale")
    if "GIT binary patch" in text or "Binary files " in text:
        fail("binary Git patches are forbidden; use granted ASSETS only")
    for line in text.splitlines():
        if line.startswith("diff --git "):
            # Standard git --no-ext-diff unified headers; quoted filenames are deliberately disallowed
            m = re.match(r"^diff --git a/(\S+) b/(\S+)$", line)
            if not m:
                fail("diff header must use unquoted simple Git paths; for spaces use FILES/ plus NO_PATCH proposal")
            for raw in m.groups():
                p = checked_relative(raw)
                if p.parts[0] in ("AGENT_INBOX", ".git"):
                    fail("PATCH.diff must target project content, not governance/git internals")

def check_asset_metadata(root: Path, submission: Path, manifest: dict[str, str], assets: list[Path]) -> None:
    if not assets:
        return
    registry = root / "AGENT_INBOX" / "ASSET_GRANTS.json"
    if not registry.is_file():
        fail("ASSET_GRANTS.json missing; no asset permission can be inferred")
    try:
        grants = json.loads(registry.read_text(encoding="utf-8"))["grants"]
        entries = json.loads((submission / "ASSET_MANIFEST.json").read_text(encoding="utf-8"))
    except (KeyError, ValueError, OSError) as exc:
        fail(f"invalid grant registry or asset manifest: {exc}")
    if not isinstance(grants, list):
        fail("ASSET_GRANTS.json 'grants' must be an array")
    grant_id = manifest.get("asset_grant", "")
    if not grant_id or grant_id.lower() == "none":
        fail("MANIFEST.md must specify active asset_grant for ASSETS")
    grant = next((g for g in grants if isinstance(g, dict) and g.get("grant_id") == grant_id), None)
    if not grant or grant.get("status") != "active" or grant.get("agent_id") != manifest["agent_id"]:
        fail("asset grant missing, revoked or assigned to a different agent")
    if not isinstance(entries, dict) or entries.get("grant_id") != grant_id or not isinstance(entries.get("assets"), list):
        fail("ASSET_MANIFEST.json grant_id/assets mismatch")
    try:
        max_files = int(grant["max_asset_files"])
        max_file = int(grant["max_file_bytes"])
        max_total = int(grant["max_total_bytes"])
    except (KeyError, TypeError, ValueError):
        fail("grant quotas are invalid")
    if min(max_files, max_file, max_total) < 1:
        fail("grant quotas must be positive")
    allowed_ext = set(str(x).lower() for x in grant.get("allowed_extensions", []))
    allowed_license = set(grant.get("allowed_licenses", []))
    if len(assets) > max_files:
        fail("asset file count exceeds grant")
    total_bytes = 0
    asset_set: set[str] = set()
    for file in assets:
        rel = file.relative_to(submission).as_posix()
        asset_set.add(rel)
        if file.suffix.lower() not in allowed_ext or file.suffix.lower() in ARCHIVE_SUFFIXES | SECRET_SUFFIXES:
            fail(f"asset extension not granted: {rel}")
        stat = file.stat()
        if stat.st_size > max_file:
            fail(f"asset exceeds per-file quota: {rel}")
        total_bytes += stat.st_size
        with file.open("rb") as handle:
            if handle.read(48).startswith(b"version https://git-lfs.github.com/spec/v1"):
                fail(f"LFS pointer is not an actual payload: {rel}")
    if total_bytes > max_total:
        fail("total assets exceed grant")
    entry_paths: set[str] = set()
    aliases: set[str] = set()
    for entry in entries["assets"]:
        if not isinstance(entry, dict):
            fail("asset manifest entry must be an object")
        rel = entry.get("path")
        p = checked_relative(rel)
        if p.parts[0] != "ASSETS" or len(p.parts) < 2:
            fail(f"asset manifest path outside ASSETS: {rel}")
        if rel in entry_paths:
            fail(f"duplicate asset path: {rel}")
        entry_paths.add(rel)
        alias = entry.get("alias")
        if not isinstance(alias, str) or not alias.strip() or alias in aliases:
            fail(f"missing/duplicate asset alias: {rel}")
        aliases.add(alias)
        if not isinstance(entry.get("source_url"), str) or not entry["source_url"].startswith("https://"):
            fail(f"source URL must be HTTPS: {rel}")
        license_id = entry.get("license")
        if license_id not in allowed_license:
            fail(f"asset license not granted: {rel}")
        if license_id == "CC-BY-4.0" and not str(entry.get("attribution", "")).strip():
            fail(f"attribution required: {rel}")
        if not isinstance(entry.get("purpose"), str) or not entry["purpose"].strip():
            fail(f"purpose missing: {rel}")
        if not isinstance(entry.get("sha256"), str) or not SHA64.fullmatch(entry["sha256"]):
            fail(f"invalid SHA256: {rel}")
        if type(entry.get("bytes")) is not int or entry["bytes"] < 0:
            fail(f"invalid byte count: {rel}")
        f = submission / rel
        ensure_inside(submission, f)
        if not f.is_file() or f.is_symlink():
            fail(f"referenced asset missing or symlink: {rel}")
        digest = hashlib.sha256()
        with f.open("rb") as src:
            for chunk in iter(lambda: src.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest().lower() != entry["sha256"].lower() or f.stat().st_size != entry["bytes"]:
            fail(f"asset hash or byte mismatch: {rel}")
    if entry_paths != asset_set:
        fail(f"asset manifest/file mismatch: missing={sorted(asset_set-entry_paths)} extra={sorted(entry_paths-asset_set)}")

def validate_submission(repo: Path, rel: str) -> dict[str, str]:
    parts = checked_relative(rel).parts
    if len(parts) != 4 or parts[:2] != ("AGENT_INBOX", "submissions"):
        fail("submission must be AGENT_INBOX/submissions/<agent-id>/<task-id>")
    if parts[2].lower() in RESERVED_IDS or parts[3].lower() in RESERVED_IDS:
        fail("reserved agent/task identifier")
    if not IDENT.fullmatch(parts[2]) or not IDENT.fullmatch(parts[3]):
        fail("bad submission path identifiers")
    sub = repo.joinpath(*parts)
    ensure_inside(repo, sub)
    if not sub.is_dir() or sub.is_symlink():
        fail(f"submission directory not found or symlink: {rel}")
    all_files: list[Path] = []
    for directory, dirs, files in os.walk(sub, followlinks=False):
        for name in dirs + files:
            item = Path(directory) / name
            if item.is_symlink():
                fail(f"Inbox symlink is forbidden: {item.relative_to(repo)}")
        for name in files:
            all_files.append(Path(directory) / name)
    present = {p.name for p in sub.iterdir() if p.is_file()}
    missing = set(REQUIRED) - present
    if missing:
        fail(f"missing required submission files: {sorted(missing)}")
    if len({p.relative_to(sub).as_posix().casefold() for p in all_files}) != len(all_files):
        fail("case-insensitive duplicate paths detected")
    asset_files: list[Path] = []
    for item in all_files:
        rel_item = item.relative_to(sub).as_posix()
        parts_i = PurePosixPath(rel_item).parts
        suffix = item.suffix.lower()
        if suffix in ARCHIVE_SUFFIXES or suffix in SECRET_SUFFIXES or item.name.startswith(".env"):
            fail(f"archive, secret-like or environment file is forbidden: {rel_item}")
        if parts_i[0] == "ASSETS":
            asset_files.append(item)
        else:
            if item.stat().st_size > MAX_TEXT_BYTES:
                fail(f"text file exceeds 2 MiB: {rel_item}")
            raw = item.read_bytes()
            if b"\x00" in raw:
                fail(f"binary outside ASSETS: {rel_item}")
            try:
                raw.decode("utf-8")
            except UnicodeError:
                fail(f"non-UTF-8 file outside ASSETS: {rel_item}")
    if asset_files and not (sub / "ASSET_MANIFEST.json").is_file():
        fail("asset payload requires ASSET_MANIFEST.json")
    manifest = parse_manifest(sub / "MANIFEST.md")
    if manifest["agent_id"] != parts[2] or manifest["task_id"] != parts[3]:
        fail("submission path / manifest IDs mismatch")
    check_patch((sub / "PATCH.diff").read_text(encoding="utf-8"))
    check_asset_metadata(repo, sub, manifest, asset_files)
    record = load_record(sub / "STUDY_RECORD.json")
    validate_study(repo, record, agent_id=manifest["agent_id"], task_id=manifest["task_id"],
                   base_main_sha=manifest["base_main_sha"])
    return manifest

def validate_strict(repo: Path, args: argparse.Namespace) -> None:
    branch = args.head_ref
    if not (SHA40.fullmatch(args.base) and SHA40.fullmatch(args.head)):
        fail("--base and --head must be 40-hex commit SHAs")
    # Ensure commits exist and ancestry calculation can be performed.
    git(repo, "cat-file", "-e", args.base + "^{commit}")
    git(repo, "cat-file", "-e", args.head + "^{commit}")
    changed_bytes = subprocess.run(
        ["git", "-C", str(repo), "diff", "--no-renames", "--name-only", "-z", args.base, args.head],
        capture_output=True,
    )
    if changed_bytes.returncode:
        fail("could not obtain Git diff")
    try:
        changed = [item.decode("utf-8") for item in changed_bytes.stdout.split(b"\x00") if item]
    except UnicodeError:
        fail("non-UTF-8 filenames are unsupported")
    if not changed:
        fail("no changed files")
    if ADMIN_BRANCH.fullmatch(branch):
        if not args.pr_title.startswith("[GOVERNOR-ADMIN]"):
            fail("admin branch needs [GOVERNOR-ADMIN] PR title")
        for item in changed:
            parts = checked_relative(item).parts
            if item == "AGENTS.md" or item == ".github/workflows/agent-inbox-gate.yml":
                continue
            if len(parts) >= 2 and parts[0] == "AGENT_INBOX" and parts[1] not in ("submissions",):
                continue
            fail(f"admin PR has unauthorized path: {item}")
        print(f"AGENT_INBOX_ADMIN_GATE_PASS changed={len(changed)}; owner review still required")
        return
    match = DROP_BRANCH.fullmatch(branch)
    if not match:
        fail("Inbox PR must use agent-drop/<agent-id>/<task-id> or owner-controlled admin/*")
    agent, task = match.groups()
    if args.pr_title.strip() != f"[AGENT-DROP] {agent} / {task}":
        fail("PR title must exactly match [AGENT-DROP] <agent-id> / <task-id>")
    expected_root = f"AGENT_INBOX/submissions/{agent}/{task}"
    for name in changed:
        p = checked_relative(name)
        if len(p.parts) < 5 or "/".join(p.parts[:4]) != expected_root:
            fail(f"out-of-bound changed path: {name}")
    data = validate_submission(repo, expected_root)
    base_manifest = data["base_main_sha"].lower()
    git(repo, "cat-file", "-e", base_manifest + "^{commit}")
    ancestor = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", base_manifest, args.base])
    if ancestor.returncode:
        fail("manifest base_main_sha is not an ancestor of target PR base commit")
    print(f"AGENT_INBOX_GATE_PASS root={expected_root} base_main_sha={base_manifest} changed={len(changed)}")

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--repo", default=".", help="repository root (defaults to cwd)")
    p.add_argument("--local", action="store_true", help="validate a local package without a PR")
    p.add_argument("--submission", help="local relative Inbox submission path")
    p.add_argument("--base", help="PR target commit SHA")
    p.add_argument("--head", help="PR head commit SHA")
    p.add_argument("--head-ref", help="PR source branch")
    p.add_argument("--pr-title", help="PR title")
    args = p.parse_args()
    repo = Path(args.repo).resolve()
    try:
        if not repo.is_dir():
            fail(f"repository directory does not exist: {repo}")
        if args.local:
            if not args.submission:
                fail("--local requires --submission")
            record = validate_submission(repo, args.submission)
            print(f"AGENT_INBOX_LOCAL_GATE_PASS agent={record['agent_id']} task={record['task_id']} (no remote/CI verification)")
        else:
            if not all((args.base, args.head, args.head_ref, args.pr_title)):
                fail("strict mode requires --base --head --head-ref --pr-title")
            validate_strict(repo, args)
        return 0
    except (GateFail, StudyFail, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"AGENT_INBOX_GATE_FAIL: {exc}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    sys.exit(main())
