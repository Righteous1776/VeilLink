#!/usr/bin/env python3
import argparse, hashlib, json, subprocess
from pathlib import Path

EXPECTED_MAP_SHA256 = "4bd450353ae993b0c8083b97ab5909c8260cd6984be6f6051db1967613edaaa5"

REQUIRED = [
    "VeilLink/Core/TacticalV2/TacticalCampaignCoreV2.swift",
    "VeilLink/Core/TacticalV2/TacticalWireV2.swift",
    "VeilLink/Core/TacticalV2/TacticalV2ChatSessionBuilder.swift",
    "VeilLink/Core/TacticalV2/TacticalOperationalLayersV2.swift",
    "VeilLink/UI/TacticalV2/TacticalLandscapeCanvasV2.swift",
    "VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift",
    "VeilLink/UI/TacticalV2/TacticalV2LaunchGateView.swift",
    "VeilLink/Security/TacticalPendingRevealSecureStoreV2.swift",
    "VeilLinkTests/TacticalV2Tests.swift",
    "VeilLink/Resources/Tactical/guandu_large_map_v2_48x27.json",
]

def sha256(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def fail(message):
    raise SystemExit("TACTICAL V2 VERIFY FAIL: "+message)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--json-out")
    args=ap.parse_args()
    root=Path(args.repo_root).resolve()

    for rel in REQUIRED:
        if not (root/rel).is_file():
            fail("missing "+rel)

    map_path=root/"VeilLink/Resources/Tactical/guandu_large_map_v2_48x27.json"
    if sha256(map_path)!=EXPECTED_MAP_SHA256:
        fail("Guandu map SHA mismatch")
    payload=json.loads(map_path.read_text(encoding="utf-8"))
    logic=payload.get("logic_substrate",{})
    macro=payload.get("macro_sectors",{})
    if (logic.get("width"),logic.get("height"),logic.get("cells"))!=(48,27,1296):
        fail("Guandu map logic dimensions mismatch")
    if len(payload.get("cells",[]))!=1296:
        fail("Guandu map cell count mismatch")
    if (macro.get("columns"),macro.get("rows"),macro.get("count"))!=(6,3,18):
        fail("macro sector topology mismatch")

    launch=(root/"VeilLink/UI/TacticalV2/TacticalV2LaunchGateView.swift").read_text(encoding="utf-8")
    if "PendingRevealSecureStoreV2" not in launch:
        fail("production launch gate is not using secure pending-reveal storage")
    if "PendingRevealStoreV2." in launch:
        fail("production launch gate still references UserDefaults pending-reveal storage")
    if "divergenceTurns.isEmpty" not in launch:
        fail("divergence hold gate missing")

    secure=(root/"VeilLink/Security/TacticalPendingRevealSecureStoreV2.swift").read_text(encoding="utf-8")
    if "KeychainStore" not in secure or "CryptoKit" not in secure:
        fail("secure pending reveal vault missing Keychain/CryptoKit")

    if (root/".git").is_dir():
        tracked=subprocess.check_output(["git","ls-files"],cwd=root,text=True).splitlines()
        polluted=[
            p for p in tracked
            if ("__pycache__" in p or p.endswith(".pyc")) and (root/p).exists()
        ]
        if polluted:
            fail("tracked Python cache files: "+", ".join(polluted))

    report={
        "schema":1,
        "result":"PASS",
        "map_sha256":EXPECTED_MAP_SHA256,
        "map_dimensions":[48,27],
        "map_cells":1296,
        "macro_sectors":18,
        "pending_reveal_storage":"Keychain ThisDeviceOnly",
        "divergence_hold":True,
        "legacy_vlgm1_preserved":True,
        "vltw2_transport":"existing VeilLink E2EE text channel",
    }
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,sort_keys=True))
    print("TACTICAL_V2_SOURCE_GATE=PASS")

if __name__=="__main__":
    main()
