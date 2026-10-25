# Test plan

## Executable local checks

1. Swift 6 strict-concurrency typecheck of `VeilFeatureRegistry.swift`.
2. Swift frontend parse of the proposed SwiftUI and XCTest sources.
3. Compile and run `VALIDATION/FeatureRegistryHarness.swift` with 5,000 descriptors.
4. Verify 10,000 indexed ID lookups, domain/search paging, pack conflict audit and legacy-device render adaptation.
5. `git apply --check --whitespace=error-all PATCH.diff` against exact base main.
6. `git diff --check` on the Inbox commit.

## Required Governor integration checks

1. Regenerate the Xcode project and build the iOS 15 simulator target.
2. Run the complete VeilLink XCTest inventory, not only the three proposed files.
3. Verify dark/light, Dynamic Type, VoiceOver labels, Reduce Motion and keyboard search.
4. Verify Feature Library paging, launch gates and destination routing on iPhone 7 / iOS 15.8.3.
5. Run Instruments for scroll memory, allocations and frame pacing with all accepted V27 packs registered.
6. Verify God Mode high quality and critical-thermal fail-safe behavior on device.

Linux timing values are informational and must not be presented as iPhone performance evidence.
