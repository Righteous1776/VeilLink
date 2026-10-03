#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import plistlib
from pathlib import Path
import subprocess
import sys
import zipfile

MAX_IPA_BYTES = 80 * 1024 * 1024
MAX_APP_BYTES = 120 * 1024 * 1024
EXPECTED_VERSION = "26.10"
EXPECTED_BUILD = "56"
EXPECTED_TACTICAL_MAP_SHA256 = "4bd450353ae993b0c8083b97ab5909c8260cd6984be6f6051db1967613edaaa5"
EXPECTED_A10_M5_SOURCE_MODEL_HASH = "c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4"
EXPECTED_A10_M5_FILES = {
    "ios_integration_manifest.json": "b48c86cf4fc8df3a78ed88f6afc69ee6ecf622663bbb361bace3ead9206cc6f5",
    "language_weights.bin": "3228384ef72a809e5725a54f4288ba0457288cb695338966eb679b82221e3e26",
    "model.json": "54a779895b09a74e5996dec0dad5d47dee4750b596754bb440cb01801f05cdb2",
    "runtime_predictor_model.json": "3b43cf41855831b2c4c059542a319907a2bd3ccd7300364cb567b85010f55b0c",
    "runtime_predictor_weights.bin": "74b1f91cb90c95823c882c284f4c369f3f815f90e8d6e87e06d5038a84684204",
    "sqlite_predictor_model.json": "cec8ab11b175151318b4bffcd2ded29aa3b70bacefdd68417e80d0bdb3b0170d",
    "sqlite_predictor_weights.bin": "549026ee043e99d11cc4e8110ac6167a084a166978761e98f6c6047929e4afb4",
    "vocab.json": "fbf7edf8ffe3e1ed5d7e79baa5b118b8fc38ed646dbb684f0615349d611dec50",
}

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

def expected_release_identity(project_path):
    text = Path(project_path).read_text(encoding="utf-8")
    version_match = re.search(r'^\s*MARKETING_VERSION:\s*["\']?([^"\'\s#]+)', text, re.MULTILINE)
    build_match = re.search(r'^\s*CURRENT_PROJECT_VERSION:\s*["\']?([^"\'\s#]+)', text, re.MULTILINE)
    if not version_match or not build_match:
        fail("project.yml release identity is missing")
    version = version_match.group(1)
    build = build_match.group(1)
    if (version, build) != (EXPECTED_VERSION, EXPECTED_BUILD):
        fail(
            "recovery identity regression: "
            f"expected {EXPECTED_VERSION} ({EXPECTED_BUILD}), got {version} ({build})"
        )
    return version, build


def verify_a10_m5_assets(app):
    paths = {}
    hashes = {}
    for name, expected_hash in EXPECTED_A10_M5_FILES.items():
        path = find_one(app, name)
        actual_hash = sha256_file(path)
        if actual_hash != expected_hash:
            fail(f"A10 Ultra M5 asset SHA mismatch: {name}")
        paths[name] = path
        hashes[name] = actual_hash

    try:
        metadata = json.loads(paths["ios_integration_manifest.json"].read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid A10 Ultra M5 integration manifest: {exc}")

    expected_metadata = {
        "schema": "VEILLINK_A10_ULTRA_M5_IOS_ASSET_V1",
        "state": "TRAINED_COGNITION_SHADOW",
        "production_cutover": "DENY",
        "source_model_hash": EXPECTED_A10_M5_SOURCE_MODEL_HASH,
        "flat_language_weights_sha256": EXPECTED_A10_M5_FILES["language_weights.bin"],
        "predictor_weights_sha256": EXPECTED_A10_M5_FILES["runtime_predictor_weights.bin"],
        "sqlite_predictor_weights_sha256": EXPECTED_A10_M5_FILES["sqlite_predictor_weights.bin"],
        "vocab_sha256": EXPECTED_A10_M5_FILES["vocab.json"],
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            fail(f"A10 Ultra M5 manifest mismatch: {key}")

    return {
        "paths": paths,
        "report": {
            "schema": metadata["schema"],
            "state": metadata["state"],
            "production_cutover": metadata["production_cutover"],
            "source_model_hash": metadata["source_model_hash"],
            "asset_sha256": hashes,
        },
    }


def verify_app(app, expected_version, expected_build):
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
    actual_version = str(info.get("CFBundleShortVersionString", ""))
    actual_build = str(info.get("CFBundleVersion", ""))
    if actual_version != expected_version:
        fail(f"expected version {expected_version}, got {actual_version}")
    if actual_build != expected_build:
        fail(f"expected build {expected_build}, got {actual_build}")

    linked = subprocess.check_output(["otool", "-L", str(app / "VeilLink")], text=True)
    if "llama.framework" in linked:
        fail("Core executable unexpectedly links llama.framework")

    tactical = find_one(app, "guandu_large_map_v2_48x27.json")
    if sha256_file(tactical) != EXPECTED_TACTICAL_MAP_SHA256:
        fail("Tactical V2 map SHA mismatch")

    a10_m5 = verify_a10_m5_assets(app)

    app_bytes = directory_bytes(app)
    if app_bytes > MAX_APP_BYTES:
        fail(f"Core app payload too large: {app_bytes} > {MAX_APP_BYTES}")

    return {
        "bundle_id": "studio.zeo.veillink",
        "version": actual_version,
        "build": actual_build,
        "payload_bytes": app_bytes,
        "payload_budget_bytes": MAX_APP_BYTES,
        "executable_sha256": sha256_file(app / "VeilLink"),
        "assets_car_sha256": sha256_file(app / "Assets.car"),
        "tactical_map_sha256": EXPECTED_TACTICAL_MAP_SHA256,
        "a10_ultra_m5": a10_m5["report"],
        "heavy_ai_resources": "ABSENT",
        "llama_framework": "ABSENT",
    }

def verify_ipa(app, ipa, expected_version, expected_build):
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

        for rel in ["VeilLink", "Assets.car"]:
            entry = prefix + rel
            if entry not in names:
                fail(f"IPA missing {rel}")
            if sha256_bytes(z.read(entry)) != sha256_file(app / rel):
                fail(f"IPA/app parity mismatch: {rel}")

        try:
            packaged_info = plistlib.loads(z.read(prefix + "Info.plist"))
        except Exception as exc:
            fail(f"invalid packaged Info.plist: {exc}")
        expected_info = {
            "CFBundleIdentifier": "studio.zeo.veillink",
            "CFBundleShortVersionString": expected_version,
            "CFBundleVersion": expected_build,
            "CFBundleExecutable": "VeilLink",
            "CFBundlePackageType": "APPL",
        }
        for key, expected in expected_info.items():
            if str(packaged_info.get(key, "")) != expected:
                fail(f"packaged Info.plist mismatch: {key}")
        if not str(packaged_info.get("MinimumOSVersion", "15")).startswith("15"):
            fail("packaged Info.plist minimum OS mismatch")

        for resource_name, expected_hash in EXPECTED_A10_M5_FILES.items():
            matches = [
                name for name in names
                if name.startswith(prefix) and name.endswith("/" + resource_name)
            ]
            if len(matches) != 1:
                fail(f"expected one {resource_name} in IPA, got {len(matches)}")
            if sha256_bytes(z.read(matches[0])) != expected_hash:
                fail(f"IPA A10 Ultra M5 asset SHA mismatch: {resource_name}")

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
    parser.add_argument("--project", default="project.yml")
    args = parser.parse_args()

    app = Path(args.app).resolve()
    ipa = Path(args.ipa).resolve()

    expected_version, expected_build = expected_release_identity(args.project)
    app_report = verify_app(app, expected_version, expected_build)
    ipa_report = verify_ipa(app, ipa, expected_version, expected_build)

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
