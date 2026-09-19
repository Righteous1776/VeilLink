#!/usr/bin/env bash
set -euo pipefail

app_path="${APP_PATH:-DerivedData/Build/Products/Release-iphoneos/VeilLink.app}"
build_dir="${BUILD_DIR:-build}"
payload_dir="$build_dir/Payload"
ipa_path="$build_dir/VeilLink-unsigned.ipa"

test -d "$app_path"
test ! -d "$app_path/_CodeSignature"
test ! -e "$app_path/embedded.mobileprovision"

# Never package stale Payload/IPA bytes from an earlier run.
rm -rf "$payload_dir" "$ipa_path"
mkdir -p "$payload_dir"

ditto "$app_path" "$payload_dir/VeilLink.app"

test ! -d "$payload_dir/VeilLink.app/_CodeSignature"
test ! -e "$payload_dir/VeilLink.app/embedded.mobileprovision"

ditto -c -k --sequesterRsrc --keepParent "$payload_dir" "$ipa_path"
test -s "$ipa_path"

# Cheap structural sanity gate before the deeper Python release verifier.
unzip -t "$ipa_path" >/dev/null
unzip -l "$ipa_path" | grep -q 'Payload/VeilLink.app/Info.plist'
unzip -l "$ipa_path" | grep -q 'Payload/VeilLink.app/VeilLink'

echo "Unsigned IPA packaging PASS"
echo "ipa=$ipa_path"
shasum -a 256 "$ipa_path"
