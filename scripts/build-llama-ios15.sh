#!/usr/bin/env bash
set -euo pipefail

LLAMA_CPP_COMMIT="${LLAMA_CPP_COMMIT:-b29c606e28a01b1bc8c1351026a0fa6e616bf6c4}"
IOS_MIN_OS_VERSION="${IOS_MIN_OS_VERSION:-15.0}"
WORK_ROOT="${LLAMA_BUILD_ROOT:-${RUNNER_TEMP:-$PWD/.local-ai}/llama-cpp}"
OUTPUT_ROOT="${LLAMA_OUTPUT_ROOT:-$PWD/Vendor}"

rm -rf "$WORK_ROOT"
mkdir -p "$(dirname "$WORK_ROOT")" "$OUTPUT_ROOT"
git clone --filter=blob:none https://github.com/ggml-org/llama.cpp.git "$WORK_ROOT"
git -C "$WORK_ROOT" checkout --detach "$LLAMA_CPP_COMMIT"

python3 - "$WORK_ROOT/build-xcframework.sh" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'IOS_MIN_OS_VERSION=16.4\n'
new = 'IOS_MIN_OS_VERSION=${IOS_MIN_OS_VERSION:-16.4}\n'
if s.count(old) != 1:
    raise SystemExit(f"unexpected llama.cpp build script: iOS minimum anchor count={s.count(old)}")
p.write_text(s.replace(old, new, 1))
PY

(
  cd "$WORK_ROOT"
  IOS_MIN_OS_VERSION="$IOS_MIN_OS_VERSION" ./build-xcframework.sh ios-sim ios-device
)

test -d "$WORK_ROOT/build-apple/llama.xcframework"
rm -rf "$OUTPUT_ROOT/llama.xcframework"
ditto "$WORK_ROOT/build-apple/llama.xcframework" "$OUTPUT_ROOT/llama.xcframework"

echo "llama.cpp commit: $LLAMA_CPP_COMMIT"
echo "iOS minimum: $IOS_MIN_OS_VERSION"
echo "XCFramework: $OUTPUT_ROOT/llama.xcframework"
