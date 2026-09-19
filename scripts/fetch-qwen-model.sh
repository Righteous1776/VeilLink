#!/usr/bin/env bash
set -euo pipefail

MODEL_SHA256="${QWEN_MODEL_SHA256:-da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4}"
MODEL_REVISION="${QWEN_MODEL_REVISION:-a41486f827d17edd055fe6b3b0ba3f8d427c0519}"
MODEL_URL="${QWEN_MODEL_URL:-https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/${MODEL_REVISION}/Qwen3-0.6B-Q4_0.gguf?download=true}"
DESTINATION="${1:-VeilLink/Resources/Qwen3-0.6B-Q4_0.gguf}"
TMP="${DESTINATION}.partial"

mkdir -p "$(dirname "$DESTINATION")"
rm -f "$TMP"
curl -L --fail --retry 4 --retry-delay 3 --connect-timeout 30 \
  -o "$TMP" "$MODEL_URL"

actual="$(shasum -a 256 "$TMP" | awk '{print $1}')"
if [[ "$actual" != "$MODEL_SHA256" ]]; then
  echo "Qwen model SHA mismatch: expected $MODEL_SHA256 got $actual" >&2
  rm -f "$TMP"
  exit 1
fi

bytes="$(stat -f '%z' "$TMP")"
if (( bytes < 400 * 1024 * 1024 )); then
  echo "Qwen model unexpectedly small: $bytes bytes" >&2
  rm -f "$TMP"
  exit 1
fi

mv "$TMP" "$DESTINATION"
echo "Qwen model verified: $DESTINATION ($bytes bytes, sha256=$actual)"
