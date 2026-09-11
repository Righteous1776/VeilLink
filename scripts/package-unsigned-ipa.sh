#!/usr/bin/env bash
set -euo pipefail

app_path="DerivedData/Build/Products/Release-iphoneos/VeilLink.app"
payload_dir="build/Payload"
ipa_path="build/VeilLink-unsigned.ipa"

test -d "$app_path"
mkdir -p "$payload_dir"
ditto "$app_path" "$payload_dir/VeilLink.app"
ditto -c -k --sequesterRsrc --keepParent "$payload_dir" "$ipa_path"
test -s "$ipa_path"
