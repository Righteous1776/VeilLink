#!/usr/bin/env bash
set -euo pipefail
PBX="${1:-VeilLink.xcodeproj/project.pbxproj}"
test -s "$PBX"
grep -q 'REAL_LOCAL_AI_REQUIRED' "$PBX"
grep -q 'llama.xcframework' "$PBX"
grep -q 'Qwen3-0.6B-Q4_0.gguf' "$PBX"
echo "Local AI Xcode project gate PASS"
