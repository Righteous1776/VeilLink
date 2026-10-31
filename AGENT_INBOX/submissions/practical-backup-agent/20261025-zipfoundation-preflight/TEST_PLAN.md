# Validation and release gate

## Executed in this environment
- Swift 6.2.1, `swift-tools-version:5.9`, `swift test -j 2`: **16 XCTest passed / 0 failures** for all pure ZIP metadata policy edge cases.
- ZIPFoundation inspector Swift typecheck with a *public-API-shape stub* matching upstream ZIPFoundation 0.9.19 `Archive`, `Entry`, `extract` signatures: PASS. This is NOT a real external library build.
- Inspector / SwiftUI / 5 ZIPFoundation integration XCTest source `swiftc -frontend -parse`: PASS syntax only.
- Patch structure and exact main context checked against main SHA in GitHub.

## NOT YET executed
- Actual ZIPFoundation 0.9.19+ dependency linking, XcodeGen iOS15 target and Full XCTest.
- Five authored ZIPFoundation integration XCTest functions (real fixtures) are pending macOS Apple SDK lane.
- Real iPhone7/iPhone13 tests, memory/touch/thermal/power benchmarks.

## Governor integration acceptance
1. Test against **real legacy v1/v2** user-created ZIP backups (fresh and old) before adding the fail-closed restore guard.
2. Test good, truncated, re-ordered, duplicate-path, case-collision, symlink, traversal and CRC-corrupted ZIPs. No file writes to live DB during preflight.
3. Compare preflight memory/cold speed (<10k entries, 350MiB declared max); optional deep CRC should avoid UI main thread and keep bounded streaming memory.
4. Test Documents provider file security scope; Finder/iCloud local read, interrupted inspection, double-open, scan/dismiss, dark/light appearance, VoiceOver and iPhone7 touch overlays.
5. Confirm no regression in pre-consent black box or Keychain/SQLite continuity. Preserve existing backup password KDF hard bounds (salt 16–64, 100k–1M iterations for backup, output 32 bytes).
6. Reconcile ToolCenter shared diff with #67/#68/#70/#76/#84/#88 and Storage Center #50. **P0 #64/#65/#66** repair first, then gated integration, no automatic IPA Actions.
7. Keep CRC claims strictly scoped to archive bytes, not password correctness or successful encrypted database/key recovery.
