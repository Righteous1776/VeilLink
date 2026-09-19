#!/usr/bin/env bash
set -euo pipefail

bash scripts/build-llama-ios15.sh
bash scripts/fetch-qwen-model.sh VeilLink/Resources/Qwen3-0.6B-Q4_0.gguf
python3 scripts/write-local-ai-provenance.py
python3 scripts/make-local-ai-project.py

echo "Real local AI build inputs prepared."
