#!/usr/bin/env bash
set -euo pipefail
app="${1:-DerivedData/Build/Products/Release-iphoneos/VeilLink.app}"
[[ -d "$app" ]] || { echo "app not found: $app" >&2; exit 2; }
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$repo_root/scripts/verify-vfly-installed.py" "$app" --json-out "${2:-DUAL_BRAIN_VFLY_VERIFY.json}"
bash "$repo_root/scripts/verify-real-local-ai-app.sh" "$app"
test -s "$app/VeilFlyCore.vfly"
test -s "$app/VeilFlyLite.vfly"
test -s "$app/VeilFlyAssets.json"
test ! -e "$app/MaleCNSReference.vfly"
echo "Dual-brain app verification PASS"
