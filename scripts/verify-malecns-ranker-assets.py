#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path

EXPECTED = {
    "lite": {
        "model": "MaleCNSGameRankerLiteV1.json",
        "manifest": "MaleCNSGameRankerLiteV1.manifest.json",
        "graph_sha256": "25b4947ec6c2a33502879d92269299120b708e86110157a538f792e327b7abee",
        "deployment_eligible": True,
    },
    "core": {
        "model": "MaleCNSGameRankerCoreV1.json",
        "manifest": "MaleCNSGameRankerCoreV1.manifest.json",
        "graph_sha256": "cc8b71d824ecb7f20c821412b316262ecb4dd1faee148077c94825b5889d60de",
        "deployment_eligible": False,
    },
}

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--resources", default="VeilLink/Resources")
    parser.add_argument("--json-out")
    args = parser.parse_args()

    resources = Path(args.resources)
    report = {"schema": 1, "result": "PASS", "assets": []}

    for tier, spec in EXPECTED.items():
        model_path = resources / spec["model"]
        manifest_path = resources / spec["manifest"]
        if not model_path.is_file():
            raise SystemExit(f"missing {model_path}")
        if not manifest_path.is_file():
            raise SystemExit(f"missing {manifest_path}")

        json.loads(model_path.read_text(encoding="utf-8"))
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

        model_sha = sha256(model_path)
        if manifest.get("schema") != 1:
            raise SystemExit(f"{manifest_path}: unsupported schema")
        if manifest.get("graph_tier") != tier:
            raise SystemExit(f"{manifest_path}: tier mismatch")
        if manifest.get("graph_sha256") != spec["graph_sha256"]:
            raise SystemExit(f"{manifest_path}: graph SHA mismatch")
        if manifest.get("model_sha256") != model_sha:
            raise SystemExit(f"{manifest_path}: model SHA mismatch")
        if manifest.get("model_byte_count") != model_path.stat().st_size:
            raise SystemExit(f"{manifest_path}: model byte count mismatch")
        if manifest.get("deployment_eligible") is not spec["deployment_eligible"]:
            raise SystemExit(f"{manifest_path}: deployment gate mismatch")
        if set(manifest.get("games", [])) != {"gomoku", "xiangqi", "ludo"}:
            raise SystemExit(f"{manifest_path}: trained game set mismatch")
        if "tactical" not in set(manifest.get("excluded_games", [])):
            raise SystemExit(f"{manifest_path}: tactical must remain excluded")
        if manifest.get("connectivity_frozen") is not True:
            raise SystemExit(f"{manifest_path}: connectivity must remain frozen")
        if manifest.get("trainable") != "candidate_ranker_only":
            raise SystemExit(f"{manifest_path}: unexpected trainable scope")

        report["assets"].append({
            "tier": tier,
            "model": spec["model"],
            "model_sha256": model_sha,
            "model_bytes": model_path.stat().st_size,
            "graph_sha256": manifest["graph_sha256"],
            "deployment_eligible": manifest["deployment_eligible"],
            "validation_decisions": manifest.get("validation_decisions"),
            "vfly_delta_macro_top1": manifest.get("vfly_delta_macro_top1"),
        })

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    print(json.dumps(report, sort_keys=True))
    print("MaleCNS R7 ranker asset verification PASS")

if __name__ == "__main__":
    main()
