# Tests and acceptance

1. `git apply --check PATCH.diff` on exact base e093e7fb7ab0eb9821a014b753ab2bdc27613ec8.
2. `xcodegen generate`, standard preflight, full iOS simulator XCTest and unsigned Release iphoneos compilation (Governor only).
3. Unit: existing staging snapshot, extension reject and background 3MiB copy; added non-file URL rejection.
4. Manual iOS15.8.3/iOS26: Files / iCloud offline placeholder / third-party provider; exercise import of .vltrain.json, PNG, HTML, ZIP, backup restore; check bytes and error visibility.
5. Cancel in-flight copy and verify no retained lease after cleanup; deny permission and verify actionable surfaced error.
6. Ensure .fileImporter cancellation is not misreported as corrupted data and the current screen remains functional.

Do not claim P0 fixed until a real-device provider repro passes.
