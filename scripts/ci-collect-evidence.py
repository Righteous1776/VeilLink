#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
DIAG_RE = re.compile(
    r"(?P<file>[^:\n]+\.(?:swift|m|mm|c|cc|cpp|h)):"
    r"(?P<line>\d+):(?P<column>\d+): "
    r"(?P<severity>warning|error): (?P<message>.*)"
)

def command_output(args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()
    except Exception:
        return None

def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def normalize_line(line):
    line = ANSI_RE.sub("", line.rstrip())
    workspace = os.environ.get("GITHUB_WORKSPACE")
    if workspace:
        line = line.replace(workspace, "$GITHUB_WORKSPACE")
    return line

def collect_diagnostics(logs):
    errors = []
    warnings = []
    seen_errors = set()
    seen_warnings = set()
    for log in logs:
        try:
            text = log.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for raw in text.splitlines():
            line = normalize_line(raw)
            match = DIAG_RE.search(line)
            if not match:
                continue
            item = {
                "file": match.group("file"),
                "line": int(match.group("line")),
                "column": int(match.group("column")),
                "message": match.group("message").strip(),
                "source_log": log.name,
            }
            key = (item["file"], item["line"], item["column"], item["message"])
            if match.group("severity") == "error":
                if key not in seen_errors:
                    seen_errors.add(key)
                    errors.append(item)
            else:
                if key not in seen_warnings:
                    seen_warnings.add(key)
                    warnings.append(item)
    return errors[:250], warnings[:500]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workflow", required=True)
    parser.add_argument("--phase", default="job")
    parser.add_argument("--status", required=True)
    parser.add_argument("--artifact-dir", default="ci-artifacts")
    parser.add_argument("--output", default="ci-artifacts/CI_EVIDENCE.json")
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)
    logs = sorted(artifact_dir.glob("*.log"))
    errors, warnings = collect_diagnostics(logs)

    files = []
    for p in sorted(artifact_dir.rglob("*")):
        if not p.is_file():
            continue
        entry = {
            "path": p.relative_to(artifact_dir).as_posix(),
            "bytes": p.stat().st_size,
        }
        if p.stat().st_size <= 64 * 1024 * 1024:
            try:
                entry["sha256"] = sha256_file(p)
            except OSError:
                pass
        files.append(entry)

    report = {
        "schema": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "workflow": args.workflow,
        "phase": args.phase,
        "status": args.status,
        "git_head": command_output(["git", "rev-parse", "HEAD"]),
        "github": {
            "run_id": os.environ.get("GITHUB_RUN_ID"),
            "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
            "workflow": os.environ.get("GITHUB_WORKFLOW"),
            "event_name": os.environ.get("GITHUB_EVENT_NAME"),
            "ref": os.environ.get("GITHUB_REF"),
            "sha": os.environ.get("GITHUB_SHA"),
        },
        "runner": {
            "os": os.environ.get("RUNNER_OS"),
            "arch": os.environ.get("RUNNER_ARCH"),
        },
        "xcode": command_output(["xcodebuild", "-version"]),
        "system": command_output(["sw_vers"]),
        "diagnostics": {
            "error_count": len(errors),
            "warning_count": len(warnings),
            "errors": errors,
            "warnings": warnings,
        },
        "evidence_files": files,
    }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("CI evidence written:", out)
    print("errors=", len(errors), "warnings=", len(warnings))

if __name__ == "__main__":
    main()
