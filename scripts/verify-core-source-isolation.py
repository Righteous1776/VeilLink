#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.cwd()

CORE_SOURCE_EXCLUDES = [
    "Agent/MaleCNS",
    "Agent/Games/TrainedGamePolicyRuntime.swift",
    "Agent/Games/MaleCNSGameDecisionEncoder.swift",
    "Agent/Language/LlamaInferenceEngine.swift",
    "Agent/Language/LlamaLocalTextModelRuntime.swift",
    "Agent/Language/LlamaRuntimeConfiguration.swift",
    "Agent/Language/LlamaCancellationGate.swift",
    "Agent/Language/LocalModelCatalog.swift",
    "Agent/Language/LocalModelManager.swift",
]
CORE_TEST_EXCLUDES = [
    "MaleCNSNativeKernelTests.swift",
    "MaleCNSNativeRolloutPoolTests.swift",
    "MaleCNSVFLY1Tests.swift",
    "LocalModelCatalogTests.swift",
    "RealLocalInferenceSmokeTests.swift",
    "Fixtures/MaleCNSFixture.vfly",
    "Fixtures/MaleCNSFixture.vfly.manifest.json",
]
PRESERVE_ROOTS = [
    "VeilLink/Agent/MaleCNS",
    "Tools/AgentTraining",
    "Tools/VeilFlyBuilder",
]
PRESERVE_FILES = [
    "VeilLink/Agent/Games/TrainedGamePolicyRuntime.swift",
    "VeilLink/Agent/Games/MaleCNSGameDecisionEncoder.swift",
    "VeilLink/Agent/Language/LlamaInferenceEngine.swift",
    "VeilLink/Agent/Language/LlamaLocalTextModelRuntime.swift",
    "VeilLink/Agent/Language/LlamaRuntimeConfiguration.swift",
    "VeilLink/Agent/Language/LlamaCancellationGate.swift",
    "VeilLink/Agent/Language/LocalModelCatalog.swift",
    "VeilLink/Agent/Language/LocalModelManager.swift",
    "VeilLink/Resources/VeilFlyCore.vfly",
    "VeilLink/Resources/VeilFlyLite.vfly",
    "VeilLink/Resources/AgentModels/game_policy_ranker_v4.vlpol",
    "VeilLink/Resources/AgentModels/game_policy_ranker_v4.manifest.json",
]
FORBIDDEN_CORE_SYMBOLS = {
    "MaleCNSGraphManager": {"VeilLink/Agent/Language/LocalTextModelRuntimeFactory.swift"},
    "TrainedGamePolicyRuntime": set(),
    "MaleCNSGameDecisionEncoder": set(),
    "LocalModelCatalog": {"VeilLink/Agent/Language/LocalTextModelRuntimeFactory.swift"},
    "LocalModelManager": set(),
}


def fail(msg):
    raise SystemExit("CORE SOURCE ISOLATION FAIL: " + msg)


def sha256(path: Path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_core_excluded(path: Path):
    rel = path.relative_to(ROOT / "VeilLink").as_posix()
    for item in CORE_SOURCE_EXCLUDES:
        if rel == item or rel.startswith(item.rstrip("/") + "/"):
            return True
    return False


def preserved_files():
    result = set()
    for root in PRESERVE_ROOTS:
        p = ROOT / root
        if not p.is_dir():
            fail(f"preservation root missing: {root}")
        result.update(x for x in p.rglob("*") if x.is_file())
    for item in PRESERVE_FILES:
        p = ROOT / item
        if not p.is_file():
            fail(f"preserved file missing: {item}")
        result.add(p)
    return sorted(result)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write-manifest")
    args = ap.parse_args()

    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    for item in CORE_SOURCE_EXCLUDES:
        if f"          - {item}" not in project:
            fail(f"Core source exclusion missing: {item}")
    for item in CORE_TEST_EXCLUDES:
        if f"          - {item}" not in project:
            fail(f"Core test exclusion missing: {item}")

    generator = (ROOT / "scripts/make-local-ai-project.py").read_text(encoding="utf-8")
    if "EXPERIMENTAL_AI_RUNTIME" not in generator:
        fail("experimental project generator does not restore experimental compilation condition")
    if "test Core source anchor" not in generator:
        fail("experimental project generator does not restore full test source tree")

    for path in sorted((ROOT / "VeilLink").rglob("*.swift")):
        if is_core_excluded(path):
            continue
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        for symbol, allow in FORBIDDEN_CORE_SYMBOLS.items():
            if symbol in text and rel not in allow:
                fail(f"active Core source still references {symbol}: {rel}")

    records = []
    for path in preserved_files():
        records.append({
            "path": path.relative_to(ROOT).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    if args.write_manifest:
        target = ROOT / args.write_manifest
        target.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schema": 1,
            "checkpoint": "VeilLink V0.10.2 LEAN_RUNTIME R4",
            "policy": "preserve-in-place; excluded from Core target; no destructive migration",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "files": records,
        }
        target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("VEILLINK_CORE_SOURCE_ISOLATION_PASS")
    print(f"PRESERVED_FILE_COUNT={len(records)}")
    print(f"PRESERVED_BYTES={sum(x['bytes'] for x in records)}")

if __name__ == "__main__":
    main()
