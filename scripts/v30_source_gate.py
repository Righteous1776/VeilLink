#!/usr/bin/env python3
"""V30 release readiness audit; proposal files alone never imply shipping."""
import argparse
import json
import plistlib
import sys
import zipfile
from pathlib import Path

REQUIRED = {
    "VeilScreen": {
        "paths": [
            "VeilLink/ScreenShare/VeilScreenShareWire.swift",
            "VeilLink/ScreenShare/VeilScreenSessionWorkflow.swift",
            "VeilLink/ScreenShare/VeilScreenLegacyBroadcastHost.swift",
            "VeilScreenBroadcastUpload/VeilScreenBroadcastUploadHandler.swift",
        ],
        "product_needles": {
            "VeilLink/Security/SessionCoordinator.swift": ["screenShare", "screenMedia"],
            "VeilLink/Core/WireCodec.swift": ["screenControl", "screenMedia"],
            "VeilLink/UI/ConversationViews.swift": ["邀请屏幕共享"],
            "project.yml": ["VeilScreenBroadcastUpload", "VeilScreenBroadcastUpload/"],
        },
    },
    "ECLIPSE_V30": {
        "paths": ["VeilLink/Agent/Games/GomokuBot.swift",
                  "VeilLink/UI/GameLobbyView.swift"],
        "product_needles": {
            "VeilLink/UI/GameLobbyView.swift": [
                "gomokuThinkingControls", "gomoku.thinking.strength.slider"
            ],
            "VeilLink/Agent/Games/LocalAIGameController.swift": [
                "setGomokuThinkingStrength", "gomokuUnlimitedThinking"
            ],
        },
    },
    "FORGE_R2": {
        "paths": ["VeilLink/UI/VeilForgeVisualSystem.swift"],
        "product_needles": {
            "VeilLink/UI/VeilForgeVisualSystem.swift": [
                "VeilForgeSoftDesign", "VeilInstrumentBackground"
            ],
        },
    },
}

def audit(root, ledger, ipa=None):
    if ledger.get("schema") != "VEILLINK_V30_REVIEW_LEDGER_V1":
        raise ValueError("wrong ledger schema")
    entries = ledger.get("pull_requests", [])
    ids = [p.get("number") for p in entries]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate pull request number")
    if len(entries) != ledger.get("snapshot", {}).get("pr_count"):
        raise ValueError("snapshot PR coverage count mismatch")
    checks = {}
    for name, rules in REQUIRED.items():
        missing = [p for p in rules["paths"] if not (root / p).is_file()]
        missing_markers = []
        for path, needles in rules["product_needles"].items():
            file = root / path
            if not file.is_file():
                missing_markers.append(path + ":file")
            else:
                content = file.read_text(encoding="utf-8")
                missing_markers.extend(path + ":" + n
                                       for n in needles if n not in content)
        checks[name] = {
            "source_paths_pass": not missing and not missing_markers,
            "missing_files": missing,
            "missing_markers": missing_markers,
        }
    project = (root / "project.yml").read_text(encoding="utf-8") if (root / "project.yml").exists() else ""
    identity = {
        "version_30": 'MARKETING_VERSION: "30.0"' in project,
        "build_70": 'CURRENT_PROJECT_VERSION: "70"' in project,
    }
    compiled = {"supplied": bool(ipa), "has_app": False,
                "has_broadcast_extension": False}
    if ipa is not None:
        if not zipfile.is_zipfile(ipa):
            raise ValueError("IPA is not a readable ZIP")
        with zipfile.ZipFile(ipa) as archive:
            names = archive.namelist()
            compiled["has_app"] = "Payload/VeilLink.app/Info.plist" in names
            compiled["has_broadcast_extension"] = any(
                name.startswith("Payload/VeilLink.app/PlugIns/VeilScreenBroadcastUpload.appex/")
                for name in names
            )
            if compiled["has_app"]:
                info = plistlib.loads(archive.read("Payload/VeilLink.app/Info.plist"))
                compiled["correct_identity"] = (
                    info.get("CFBundleShortVersionString") == "30.0"
                    and str(info.get("CFBundleVersion")) == "70"
                )
    statuses = ledger.get("release_requirements", {})
    accepted = {name: statuses.get(name, {}).get("status") == "verified"
                for name in REQUIRED}
    device = ledger.get("device_acceptance", {})
    release_ready = (
        all(x["source_paths_pass"] for x in checks.values())
        and all(identity.values())
        and all(accepted.values())
        and bool(device.get("signed_two_device_pass"))
        and compiled.get("has_app", False)
        and compiled.get("has_broadcast_extension", False)
        and compiled.get("correct_identity", False)
    )
    return {
        "schema": "VEILLINK_V30_RELEASE_GATE_V1",
        "checks": checks,
        "version": identity,
        "compiled": compiled,
        "feature_acceptance": accepted,
        "signed_two_device_pass": bool(device.get("signed_two_device_pass")),
        "release_ready": release_ready,
    }

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    p.add_argument("--ledger", type=Path)
    p.add_argument("--ipa", type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--release", action="store_true")
    args = p.parse_args()
    ledger = args.ledger or args.root / "docs/engineering/V30_REVIEW_LEDGER.json"
    report = audit(args.root, json.loads(ledger.read_text(encoding="utf-8")), args.ipa)
    data = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(data, encoding="utf-8")
    print(data)
    if args.release and not report["release_ready"]:
        print("V30 RELEASE BLOCKED: do not tag, package as final, or publish", file=sys.stderr)
        return 2
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
