#!/usr/bin/env bash
set -euo pipefail

app="${1:-DerivedData/Build/Products/Release-iphoneos/VeilLink.app}"
vfly_json="${2:-DUAL_BRAIN_VFLY_VERIFY.json}"
ranker_json="${3:-DUAL_BRAIN_RANKER_VERIFY.json}"

[[ -d "$app" ]] || { echo "app not found: $app" >&2; exit 2; }

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$repo_root/scripts/verify-vfly-installed.py" "$app" --json-out "$vfly_json"
python3 "$repo_root/scripts/verify-malecns-ranker-assets.py" \
  --resources "$app" \
  --json-out "$ranker_json"
bash "$repo_root/scripts/verify-real-local-ai-app.sh" "$app"

test -s "$app/VeilFlyCore.vfly"
test -s "$app/VeilFlyLite.vfly"
test -s "$app/VeilFlyAssets.json"
test -s "$app/MaleCNSGameRankerLiteV1.json"
test -s "$app/MaleCNSGameRankerCoreV1.json"
test -s "$app/Assets.car"
test ! -e "$app/MaleCNSReference.vfly"
test ! -e "$app/brain.npz"
test ! -e "$app/weights.npz"
test ! -d "$app/_CodeSignature"
test ! -e "$app/embedded.mobileprovision"

echo "Dual-brain app verification PASS"
