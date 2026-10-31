# Risks — CI completeness R2

## Protected surfaces
This submission proposes edits to `.github/workflows/ios-ci.yml` and `project.yml` only through an advisory diff. Lane agent did not modify protected files directly. Governor must review and integrate.

## Cross-agent overlap
- #104 Gomoku XCTest mismatch; #105 release authorization. Explicitly not replicated.
- #96/#99 tests/features, #100 WebKit host, #64/#65/#66 signing and touch, #97 BLE and #103 connectivity candidates are still subject to Governor arbitration.
- New UI test target may overlap future tests introduced by Codex. Recheck branch tree.

## CI cost/performance risk
Release `iphoneos` compilation and UI tests increase macOS CI time and Action cost. Timeout changes 35→50 minutes; Governor may split as manual protected verification if budget/queue is constrained.

## Compatibility risk
XcodeGen-generated `bundle.ui-testing` target and first-launch XCUITest must be compiled and executed in Apple CI. The initial fresh-install/launch state should be isolated by the UI test runner. If it is not, adjust the fixture without deleting the P0 gate.

## Data protection/security
UI smoke must remain pre-signature only, does not grant permissions or handle credentials. Simulator evidence includes only simulator UDID (ephemeral CI device), OS and run metadata, not user device identifiers or keys. No encrypted backup or app data writes.

## Migration and package lock
Pinning ZIPFoundation to 0.9.20 (observed PR #100 resolver version) may change builds that previously used 0.9.19; perform regression on archive/import, corruption, ZIP bomb and rollback. No DB migration is proposed.

## Rollback
Governor may split/decline individual hunks. Restore original CI scripts/project when Apple CI reveals incompatibility. Never bypass the original test suite or publish to resolve errors.
