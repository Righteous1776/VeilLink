#!/usr/bin/env bash
set -euo pipefail
# Source-only acquisition — no binary/IPA or app-source mutation.
# Run only under a Governor-approved integration window on a macOS toolchain.
JPEGLI_SHA="031a0077f5799a6041004267fc12b956c1f52a20"
ROOT="${1:?Usage: vendor-jpegli-source.sh <outside-repo-workdir>}"
test ! -e "$ROOT" || { echo "Refusing to overwrite existing directory" >&2; exit 2; }
git clone --no-checkout https://github.com/google/jpegli.git "$ROOT"
git -C "$ROOT" checkout --detach "$JPEGLI_SHA"
ACTUAL="$(git -C "$ROOT" rev-parse HEAD)"
test "$ACTUAL" = "$JPEGLI_SHA" || { echo "SHA mismatch" >&2; exit 3; }
test -f "$ROOT/LICENSE" || { echo "License missing" >&2; exit 4; }
test -f "$ROOT/lib/jpegli/encode.h" || { echo "Encoder header missing" >&2; exit 5; }
printf 'Verified jpegli source %s at %s\n' "$ACTUAL" "$ROOT"
printf 'Review LICENSE/PATENTS, build static iOS arm64 + simulator slices, validate JPEG decoder interoperability before enabling.\n'
