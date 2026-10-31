#!/bin/bash
set -euo pipefail

# Prefer a deterministic newest available iPhone runtime. CI records the exact
# runtime/OS, never silently pretending this proves iOS 15 device compatibility.
# To require a specific runtime, set VEILLINK_SIMULATOR_RUNTIME (e.g. iOS-18-5).
mkdir -p ci-artifacts
xcrun simctl list devices available -j > ci-artifacts/available-simulators.json
python3 - <<'PY'
import json, os, re
from pathlib import Path

catalog = json.loads(Path("ci-artifacts/available-simulators.json").read_text())
requested = os.environ.get("VEILLINK_SIMULATOR_RUNTIME", "").strip()
candidates = []
for runtime, devices in catalog.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable") or not str(device.get("name", "")).startswith("iPhone"):
            continue
        version = tuple(int(x) for x in re.findall(r"\d+", runtime))
        candidates.append((version, runtime, str(device["name"]), str(device["udid"])))

if requested:
    candidates = [c for c in candidates if requested in c[1]]
if not candidates:
    raise SystemExit(f"No available iPhone simulator for required runtime {requested or '(any)'}.")
candidates.sort(key=lambda x: (x[0], x[1], x[2], x[3]), reverse=True)
_, runtime, name, udid = candidates[0]
result = {
    "device_name": name,
    "device_id": udid,
    "runtime": runtime,
    "requested_runtime": requested or None,
    "ios15_simulator_verified": "iOS-15-" in runtime,
    "physical_device_verified": False,
}
Path("ci-artifacts/simulator-selection.json").write_text(json.dumps(result, indent=2) + "\n")
Path("ci-artifacts/selected-simulator-id.txt").write_text(udid + "\n")
print("CI simulator selected:", name, runtime)
print("iOS 15 physical device verified: False (separate device gate)")
PY

DEVICE_ID="$(cat ci-artifacts/selected-simulator-id.txt)"
xcodebuild \
  -project VeilLink.xcodeproj \
  -scheme VeilLink \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -resultBundlePath TestResults.xcresult \
  test
