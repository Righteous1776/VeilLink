#!/usr/bin/env bash
set -euo pipefail
python3 scripts/verify-vertex35m-model.py
export IOS_MIN_OS_VERSION=15.0
export LLAMA_CPP_COMMIT=b29c606e28a01b1bc8c1351026a0fa6e616bf6c4
bash scripts/build-llama-ios15.sh
python3 scripts/make-vertex35m-project.py
test -d Vendor/llama.xcframework
test -s project.vertex35m.yml
echo "VERTEX35M_NATIVE_INPUTS_READY"
