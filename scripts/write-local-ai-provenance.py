#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import subprocess
from datetime import datetime, timezone

root = pathlib.Path.cwd()
model = root / "VeilLink/Resources/Qwen3-0.6B-Q4_0.gguf"
framework = root / "Vendor/llama.xcframework"
output = root / "VeilLink/Resources/LocalAIProvenance.json"

expected_model_sha = os.environ.get(
    "QWEN_MODEL_SHA256",
    "da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4",
)
llama_commit = os.environ.get(
    "LLAMA_CPP_COMMIT",
    "b29c606e28a01b1bc8c1351026a0fa6e616bf6c4",
)
minimum_ios = os.environ.get("IOS_MIN_OS_VERSION", "15.0")

if not model.is_file():
    raise SystemExit(f"missing model: {model}")
if not framework.is_dir():
    raise SystemExit(f"missing framework: {framework}")

h = hashlib.sha256()
with model.open("rb") as f:
    for chunk in iter(lambda: f.read(2 * 1024 * 1024), b""):
        h.update(chunk)
actual_model_sha = h.hexdigest()
if actual_model_sha != expected_model_sha:
    raise SystemExit(
        f"model SHA mismatch: expected {expected_model_sha}, got {actual_model_sha}"
    )

try:
    git_head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
except Exception:
    git_head = "unknown"

payload = {
    "schema": 1,
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "git_head": git_head,
    "runtime": {
        "engine": "llama.cpp",
        "llama_cpp_commit": llama_commit,
        "minimum_ios": minimum_ios,
        "network_required_at_runtime": False,
    },
    "model": {
        "id": "qwen3-0.6b-q4_0.gguf.v1",
        "file": model.name,
        "upstream": "ggml-org/Qwen3-0.6B-GGUF",
        "quantization": "Q4_0",
        "license": "Apache-2.0",
        "sha256": actual_model_sha,
        "bytes": model.stat().st_size,
    },
    "architecture": {
        "language_brain": "Qwen3-0.6B via llama.cpp",
        "neural_coprocessor": "MaleCNS/VFLY retained",
        "resource_governor": "VeilA9ComputeGovernor retained",
    },
}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
print(output)
