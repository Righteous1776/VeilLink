#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import plistlib
from pathlib import Path
import subprocess
import sys
import zipfile

MAX_IPA_BYTES = 80 * 1024 * 1024
MAX_APP_BYTES = 120 * 1024 * 1024
EXPECTED_TACTICAL_MAP_SHA256 = "4bd450353ae993b0c8083b97ab5909c8260cd6984be6f6051db1967613edaaa5"

FORBIDDEN_NAMES = {
    "Qwen3-0.6B-Q4_0.gguf",
    "VeilFlyCore.vfly",
    "VeilFlyLite.vfly",
    "VeilFlyAssets.json",
    "VFLYInstallationVerification.json",
    "MaleCNSGameRankerCoreV1.json",
    "MaleCNSGameRankerCoreV1.manifest.json",
    "MaleCNSGameRankerLiteV1.json",
    "MaleCNSGameRankerLiteV1.manifest.json",
    "MaleCNSReadoutCoreV1.json",
    "MaleCNSReadoutCoreV1.manifest.json",
    "MaleCNSReadoutLiteV1.json",
    "MaleCNSReadoutLiteV1.manifest.json",
    "game_policy_ranker_v4.vlpol",
    "game_policy_ranker_v4.manifest.json",
    "LocalAIProvenance.json",
    "LocalAI-THIRD-PARTY-NOTICES.txt",
    "MaleCNSReference.vfly",
    "brain.npz",
    "weights.npz",
}

def fail(message):
    print("CORE RELEASE GATE FAIL:", message, file=sys.stderr)
    raise SystemExit(1)

def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def directory_bytes(root):
    return sum(p.stat().st_size for p in root.rglob("*") if p.is_file())

def git_output(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()
    except Exception:
        return None

def find_one(root, name):
    matches = [p for p in root.rglob(name) if p.is_file()]
    if len(matches) != 1:
        fail(f"expected exactly one {name}, got {len(matches)}")
    return matches[0]

def verify_app(app):
    for rel in ["Info.plist", "VeilLink", "Assets.car"]:
        p = app / rel
        if not p.is_file() or p.stat().st_size <= 0:
            fail(f"missing/empty {rel}")

    if (app / "_CodeSignature").exists():
        fail("unsigned Core app contains _CodeSignature")
    if (app / "embedded.mobileprovision").exists():
        fail("unsigned Core app contains embedded.mobileprovision")
    if (app / "Frameworks/llama.framework").exists():
        fail("Core app must not contain llama.framework")

    found_forbidden = []
    for p in app.rglob("*"):
        if p.name in FORBIDDEN_NAMES:
            found_forbidden.append(p.relative_to(app).as_posix())
    if found_forbidden:
        fail("Core app contains AI-heavy resources: " + ", ".join(found_forbidden[:12]))

    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "studio.zeo.veillink":
        fail("bundle identifier mismatch")
    if info.get("CFBundleShortVersionString") != "0.10.10":
        fail("expected version 0.10.10")
    if str(info.get("CFBundleVersion")) != "52":
        fail("expected build 52")

    linked = subprocess.check_output(["otool", "-L", str(app / "VeilLink")], text=True)
    if "llama.framework" in linked:
        fail("Core executable unexpectedly links llama.framework")

    tactical = find_one(app, "guandu_large_map_v2_48x27.json")
    if sha256_file(tactical) != EXPECTED_TACTICAL_MAP_SHA256:
        fail("Tactical V2 map SHA mismatch")

    app_bytes = directory_bytes(app)
    if app_bytes > MAX_APP_BYTES:
        fail(f"Core app payload too large: {app_bytes} > {MAX_APP_BYTES}")

    return {
        "bundle_id": "studio.zeo.veillink",
        "version": "0.10.10",
        "build": "52",
        "payload_bytes": app_bytes,
        "payload_budget_bytes": MAX_APP_BYTES,
        "executable_sha256": sha256_file(app / "VeilLink"),
        "assets_car_sha256": sha256_file(app / "Assets.car"),
        "tactical_map_sha256": EXPECTED_TACTICAL_MAP_SHA256,
        "heavy_ai_resources": "ABSENT",
        "llama_framework": "ABSENT",
    }

def verify_ipa(app, ipa):
    if not ipa.is_file():
        fail("IPA missing")
    if ipa.stat().st_size > MAX_IPA_BYTES:
        fail(f"Core IPA too large: {ipa.stat().st_size} > {MAX_IPA_BYTES}")

    with zipfile.ZipFile(ipa, "r") as z:
        bad = z.testzip()
        if bad is not None:
            fail(f"IPA CRC failure: {bad}")
        names = z.namelist()
        prefix = "Payload/VeilLink.app/"
        if prefix + "Info.plist" not in names or prefix + "VeilLink" not in names:
            fail("IPA missing VeilLink app payload")

        for name in names:
            if Path(name).name in FORBIDDEN_NAMES:
                fail(f"IPA contains forbidden AI resource: {name}")
            if "/Frameworks/llama.framework/" in name:
                fail("IPA contains llama.framework")

        for rel in ["Info.plist", "VeilLink", "Assets.car"]:
            entry = prefix + rel
            if entry not in names:
                fail(f"IPA missing {rel}")
            if sha256_bytes(z.read(entry)) != sha256_file(app / rel):
                fail(f"IPA/app parity mismatch: {rel}")

        tactical_entries = [
            n for n in names
            if n.startswith(prefix) and n.endswith("guandu_large_map_v2_48x27.json")
        ]
        if len(tactical_entries) != 1:
            fail(f"expected one Tactical map in IPA, got {len(tactical_entries)}")
        if sha256_bytes(z.read(tactical_entries[0])) != EXPECTED_TACTICAL_MAP_SHA256:
            fail("IPA Tactical map SHA mismatch")

    return {
        "sha256": sha256_file(ipa),
        "bytes": ipa.stat().st_size,
        "budget_bytes": MAX_IPA_BYTES,
    }

def write_json(path, obj):
    Path(path).write_text(
        json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True)
    parser.add_argument("--ipa", required=True)
    parser.add_argument("--manifest", default="CORE_RELEASE_MANIFEST.json")
    parser.add_argument("--provenance", default="CORE_RELEASE_PROVENANCE.json")
    parser.add_argument("--sums", default="CORE_RELEASE_SHA256SUMS.txt")
    args = parser.parse_args()

    app = Path(args.app).resolve()
    ipa = Path(args.ipa).resolve()

    app_report = verify_app(app)
    ipa_report = verify_ipa(app, ipa)

    manifest = {
        "schema": 1,
        "result": "PASS",
        "release_eligible": True,
        "edition": "Core",
        "unsigned": True,
        "size_policy": {
            "ipa_max_bytes": MAX_IPA_BYTES,
            "app_payload_max_bytes": MAX_APP_BYTES,
        },
        "app": app_report,
        "ipa": ipa_report,
    }
    write_json(args.manifest, manifest)

    provenance = {
        "schema": 1,
        "edition": "Core",
        "git_head": git_output("git", "rev-parse", "HEAD"),
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "github_sha": os.environ.get("GITHUB_SHA"),
        "xcode": git_output("xcodebuild", "-version"),
        "ipa_sha256": ipa_report["sha256"],
        "manifest_sha256": sha256_file(Path(args.manifest)),
    }
    write_json(args.provenance, provenance)

    Path(args.sums).write_text(
        "\n".join([
            f"{sha256_file(ipa)}  {ipa.name}",
            f"{sha256_file(Path(args.manifest))}  {Path(args.manifest).name}",
            f"{sha256_file(Path(args.provenance))}  {Path(args.provenance).name}",
        ]) + "\n",
        encoding="utf-8",
    )

    print("VEILLINK_CORE_RELEASE_GATE=PASS")
    print(f"CORE_IPA_BYTES={ipa_report['bytes']}")
    print(f"CORE_APP_PAYLOAD_BYTES={app_report['payload_bytes']}")

if __name__ == "__main__":
    main()
