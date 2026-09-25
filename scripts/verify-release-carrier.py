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

EXPECTED = {
    "bundle_id": "studio.zeo.veillink",
    "version": "0.10.10",
    "build": "52",
    "qwen_sha256": "da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4",
    "tactical_map_sha256": "4bd450353ae993b0c8083b97ab5909c8260cd6984be6f6051db1967613edaaa5",
    "vfly_core_sha256": "cc8b71d824ecb7f20c821412b316262ecb4dd1faee148077c94825b5889d60de",
    "vfly_lite_sha256": "25b5047ec6c2a33502879d92269299120b708e86110157a538f792e327b7abee",
}

REQUIRED_EXACT = [
    "Info.plist",
    "VeilLink",
    "Assets.car",
    "Frameworks/llama.framework/llama",
    "VeilFlyCore.vfly",
    "VeilFlyLite.vfly",
    "VeilFlyAssets.json",
    "VFLYInstallationVerification.json",
    "MaleCNSGameRankerLiteV1.json",
    "MaleCNSGameRankerLiteV1.manifest.json",
    "MaleCNSGameRankerCoreV1.json",
    "MaleCNSGameRankerCoreV1.manifest.json",
    "LocalAIProvenance.json",
]

FORBIDDEN_NAMES = {
    "MaleCNSReference.vfly",
    "brain.npz",
    "weights.npz",
    "project.local-ai.yml",
}

def fail(message):
    print("RELEASE GATE FAIL:", message, file=sys.stderr)
    raise SystemExit(1)

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def git_output(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()
    except Exception:
        return None

def find_one_by_name(root, name):
    matches = [p for p in root.rglob(name) if p.is_file()]
    if len(matches) != 1:
        fail(f"expected exactly one {name}, got {len(matches)}")
    return matches[0]

def validate_ranker(app, tier):
    prefix = "Lite" if tier == "lite" else "Core"
    model = app / f"MaleCNSGameRanker{prefix}V1.json"
    manifest_path = app / f"MaleCNSGameRanker{prefix}V1.manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    model_sha = sha256_file(model)
    expected_graph = (
        EXPECTED["vfly_lite_sha256"] if tier == "lite"
        else EXPECTED["vfly_core_sha256"]
    )
    expected_eligible = tier == "lite"

    checks = {
        "schema": manifest.get("schema") == 1,
        "graph_tier": manifest.get("graph_tier") == tier,
        "graph_sha": manifest.get("graph_sha256") == expected_graph,
        "model_sha": manifest.get("model_sha256") == model_sha,
        "model_bytes": manifest.get("model_byte_count") == model.stat().st_size,
        "deployment_eligible": manifest.get("deployment_eligible") is expected_eligible,
        "connectivity_frozen": manifest.get("connectivity_frozen") is True,
        "trainable_scope": manifest.get("trainable") == "candidate_ranker_only",
        "games": set(manifest.get("games", [])) == {"gomoku", "xiangqi", "ludo"},
        "tactical_excluded": "tactical" in set(manifest.get("excluded_games", [])),
    }
    failed = [key for key, ok in checks.items() if not ok]
    if failed:
        fail(f"{manifest_path.name} failed: {', '.join(failed)}")

    return {
        "tier": tier,
        "model_sha256": model_sha,
        "model_bytes": model.stat().st_size,
        "graph_sha256": expected_graph,
        "deployment_eligible": expected_eligible,
    }

def verify_app(app):
    if not app.is_dir():
        fail(f"app not found: {app}")

    for rel in REQUIRED_EXACT:
        p = app / rel
        if not p.exists():
            fail(f"missing app artifact: {rel}")
        if p.is_file() and p.stat().st_size <= 0:
            fail(f"empty app artifact: {rel}")

    if (app / "_CodeSignature").exists():
        fail("unsigned carrier unexpectedly contains _CodeSignature")
    if (app / "embedded.mobileprovision").exists():
        fail("unsigned carrier unexpectedly contains embedded.mobileprovision")

    for forbidden in FORBIDDEN_NAMES:
        if list(app.rglob(forbidden)):
            fail(f"forbidden release artifact present: {forbidden}")

    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != EXPECTED["bundle_id"]:
        fail("bundle identifier mismatch")
    if info.get("CFBundleShortVersionString") != EXPECTED["version"]:
        fail("version mismatch")
    if str(info.get("CFBundleVersion")) != EXPECTED["build"]:
        fail("build number mismatch")

    minimum = str(info.get("MinimumOSVersion", "15.0"))
    if not minimum.startswith("15."):
        fail(f"unexpected MinimumOSVersion: {minimum}")

    icons = info.get("CFBundleIcons", {})
    ipad_icons = info.get("CFBundleIcons~ipad", {})
    icon_names = {
        icons.get("CFBundlePrimaryIcon", {}).get("CFBundleIconName"),
        ipad_icons.get("CFBundlePrimaryIcon", {}).get("CFBundleIconName"),
    }
    icon_names.discard(None)
    if icon_names and "AppIcon" not in icon_names:
        fail(f"compiled app icon name mismatch: {sorted(icon_names)}")

    qwen = find_one_by_name(app, "Qwen3-0.6B-Q4_0.gguf")
    notices = find_one_by_name(app, "LocalAI-THIRD-PARTY-NOTICES.txt")
    qwen_sha = sha256_file(qwen)
    if qwen_sha != EXPECTED["qwen_sha256"]:
        fail(f"Qwen SHA mismatch: {qwen_sha}")

    tactical_map = find_one_by_name(app, "guandu_large_map_v2_48x27.json")
    tactical_map_sha = sha256_file(tactical_map)
    if tactical_map_sha != EXPECTED["tactical_map_sha256"]:
        fail(f"Tactical map SHA mismatch: {tactical_map_sha}")

    core_sha = sha256_file(app / "VeilFlyCore.vfly")
    lite_sha = sha256_file(app / "VeilFlyLite.vfly")
    if core_sha != EXPECTED["vfly_core_sha256"]:
        fail("VeilFlyCore SHA mismatch")
    if lite_sha != EXPECTED["vfly_lite_sha256"]:
        fail("VeilFlyLite SHA mismatch")

    vfly_verify = json.loads((app / "VFLYInstallationVerification.json").read_text(encoding="utf-8"))
    if vfly_verify.get("result") != "PASS":
        fail("VFLYInstallationVerification is not PASS")

    provenance = json.loads((app / "LocalAIProvenance.json").read_text(encoding="utf-8"))
    if provenance.get("model", {}).get("sha256") not in (None, EXPECTED["qwen_sha256"]):
        fail("LocalAIProvenance model SHA mismatch")

    rankers = [validate_ranker(app, "lite"), validate_ranker(app, "core")]

    executable = app / "VeilLink"
    linked = subprocess.check_output(["otool", "-L", str(executable)], text=True)
    if "llama.framework/llama" not in linked:
        fail("VeilLink executable is not linked against llama.framework")

    strings = subprocess.check_output(["strings", str(executable)], text=True, errors="replace")
    if "qwen3-0.6b-q4_0.gguf.v1" not in strings:
        fail("compiled runtime model identifier missing")

    return {
        "bundle_id": EXPECTED["bundle_id"],
        "version": EXPECTED["version"],
        "build": EXPECTED["build"],
        "minimum_os": minimum,
        "executable_sha256": sha256_file(executable),
        "assets_car_sha256": sha256_file(app / "Assets.car"),
        "app_icon_compiled": True,
        "qwen": {
            "relative_path": qwen.relative_to(app).as_posix(),
            "sha256": qwen_sha,
            "bytes": qwen.stat().st_size,
        },
        "notices": notices.relative_to(app).as_posix(),
        "tactical_v2": {
            "map_relative_path": tactical_map.relative_to(app).as_posix(),
            "map_sha256": tactical_map_sha,
            "map_dimensions": [48, 27],
            "fow": "redacted-player-view",
            "wire_protocol": "VLTW2-over-existing-E2EE",
        },
        "llama_framework_sha256": sha256_file(app / "Frameworks/llama.framework/llama"),
        "vfly": {
            "core_sha256": core_sha,
            "lite_sha256": lite_sha,
        },
        "rankers": rankers,
    }

def verify_ipa(app, ipa, app_report):
    if not ipa.is_file() or ipa.stat().st_size <= 0:
        fail(f"IPA not found/empty: {ipa}")

    with zipfile.ZipFile(ipa, "r") as z:
        bad = z.testzip()
        if bad is not None:
            fail(f"IPA CRC failure: {bad}")

        names = z.namelist()
        app_roots = sorted({
            "/".join(name.split("/")[:2])
            for name in names
            if name.startswith("Payload/") and ".app/" in name
        })
        if app_roots != ["Payload/VeilLink.app"]:
            fail(f"unexpected IPA app roots: {app_roots}")

        prefix = "Payload/VeilLink.app/"
        forbidden = [
            n for n in names
            if n.startswith(prefix)
            and (
                "/_CodeSignature/" in n
                or n.endswith("/embedded.mobileprovision")
                or Path(n).name in FORBIDDEN_NAMES
            )
        ]
        if forbidden:
            fail(f"forbidden IPA entries: {forbidden[:8]}")

        # Exact carrier parity for critical resources.
        critical = [
            "Info.plist",
            "VeilLink",
            "Assets.car",
            "Frameworks/llama.framework/llama",
            "VeilFlyCore.vfly",
            "VeilFlyLite.vfly",
            "VeilFlyAssets.json",
            "VFLYInstallationVerification.json",
            "MaleCNSGameRankerLiteV1.json",
            "MaleCNSGameRankerLiteV1.manifest.json",
            "MaleCNSGameRankerCoreV1.json",
            "MaleCNSGameRankerCoreV1.manifest.json",
            "LocalAIProvenance.json",
        ]
        parity = {}
        for rel in critical:
            entry = prefix + rel
            if entry not in names:
                fail(f"IPA missing critical entry: {entry}")
            app_sha = sha256_file(app / rel)
            ipa_sha = sha256_bytes(z.read(entry))
            if app_sha != ipa_sha:
                fail(f"IPA/app parity mismatch: {rel}")
            parity[rel] = app_sha

        qwen_entries = [n for n in names if n.startswith(prefix) and n.endswith("/Qwen3-0.6B-Q4_0.gguf")]
        if not qwen_entries:
            qwen_entries = [n for n in names if n == prefix + "Qwen3-0.6B-Q4_0.gguf"]
        if len(qwen_entries) != 1:
            fail(f"expected one Qwen IPA entry, got {len(qwen_entries)}")
        if sha256_bytes(z.read(qwen_entries[0])) != EXPECTED["qwen_sha256"]:
            fail("IPA Qwen SHA mismatch")

        tactical_entries = [n for n in names if n.startswith(prefix) and n.endswith("guandu_large_map_v2_48x27.json")]
        if len(tactical_entries) != 1:
            fail(f"expected one Tactical V2 map IPA entry, got {len(tactical_entries)}")
        if sha256_bytes(z.read(tactical_entries[0])) != EXPECTED["tactical_map_sha256"]:
            fail("IPA Tactical V2 map SHA mismatch")

    return {
        "sha256": sha256_file(ipa),
        "bytes": ipa.stat().st_size,
        "critical_parity": parity,
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
    parser.add_argument("--manifest", default="RELEASE_MANIFEST.json")
    parser.add_argument("--provenance", default="RELEASE_PROVENANCE.json")
    parser.add_argument("--sums", default="RELEASE_SHA256SUMS.txt")
    args = parser.parse_args()

    app = Path(args.app).resolve()
    ipa = Path(args.ipa).resolve()

    app_report = verify_app(app)
    ipa_report = verify_ipa(app, ipa, app_report)

    manifest = {
        "schema": 1,
        "result": "PASS",
        "release_eligible": True,
        "unsigned": True,
        "app": app_report,
        "ipa": ipa_report,
        "required_release_gates": {
            "standard_ci": "must already be PASS via workflow preflight",
            "real_qwen_smoke": "must already be PASS in this heavy workflow",
            "dual_brain_app_verification": "PASS",
            "carrier_content_verification": "PASS",
        },
    }
    write_json(args.manifest, manifest)

    xcode = git_output("xcodebuild", "-version")
    provenance = {
        "schema": 1,
        "git_head": git_output("git", "rev-parse", "HEAD"),
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "github_workflow": os.environ.get("GITHUB_WORKFLOW"),
        "github_sha": os.environ.get("GITHUB_SHA"),
        "runner_os": os.environ.get("RUNNER_OS"),
        "runner_arch": os.environ.get("RUNNER_ARCH"),
        "xcode": xcode,
        "llama_cpp_commit": os.environ.get("LLAMA_CPP_COMMIT"),
        "qwen_model_revision": os.environ.get("QWEN_MODEL_REVISION"),
        "release_manifest_sha256": sha256_file(Path(args.manifest)),
        "ipa_sha256": ipa_report["sha256"],
    }
    write_json(args.provenance, provenance)

    sums = [
        f"{sha256_file(ipa)}  {ipa.name}",
        f"{sha256_file(Path(args.manifest))}  {Path(args.manifest).name}",
        f"{sha256_file(Path(args.provenance))}  {Path(args.provenance).name}",
    ]
    Path(args.sums).write_text("\n".join(sums) + "\n", encoding="utf-8")

    print("VEILLINK_RELEASE_GATE=PASS")
    print(f"IPA_SHA256={ipa_report['sha256']}")
    print(f"RELEASE_MANIFEST={args.manifest}")
    print(f"RELEASE_PROVENANCE={args.provenance}")

if __name__ == "__main__":
    main()
