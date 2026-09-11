#!/bin/bash
set -euo pipefail

DEVICE_ID="$({ xcrun simctl list devices available -j || true; } | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and str(device.get("name", "")).startswith("iPhone"):
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
')"

if [[ -z "$DEVICE_ID" ]]; then
  echo "No available iPhone simulator found." >&2
  exit 1
fi

echo "Using iOS Simulator: $DEVICE_ID"
xcodebuild \
  -project VeilLink.xcodeproj \
  -scheme VeilLink \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -resultBundlePath TestResults.xcresult \
  test
