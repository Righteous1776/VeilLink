#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-DerivedData/Build/Products/Release-iphoneos/VeilLink.app}"
MODEL_SHA256="${QWEN_MODEL_SHA256:-da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4}"

test -d "$APP_PATH"
model="$(find "$APP_PATH" -type f -name 'Qwen3-0.6B-Q4_0.gguf' -print -quit)"
test -n "$model"
actual="$(shasum -a 256 "$model" | awk '{print $1}')"
[[ "$actual" == "$MODEL_SHA256" ]]

test -s "$APP_PATH/Frameworks/llama.framework/llama"
test -s "$APP_PATH/LocalAIProvenance.json"
otool -L "$APP_PATH/VeilLink" | grep -q 'llama.framework/llama'
strings "$APP_PATH/VeilLink" | grep 'qwen3-0.6b-q4_0.gguf.v1' >/dev/null
find "$APP_PATH" -type f -name 'LocalAI-THIRD-PARTY-NOTICES.txt' -print -quit | grep -q .

test ! -d "$APP_PATH/_CodeSignature"

echo "Real local AI app verification PASS"
echo "model=$model"
echo "sha256=$actual"
