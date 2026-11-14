# Tests and Acceptance

- Proposed automated test: `VeilFileIntegrityEngineTests.testAlreadyCancelledInspectionDoesNotReturnDigest`.
- Run existing `VeilFileIntegrityEngineTests` (known hashes, empty files, large-file chunking, nonregular rejection, reports).
- Run `VeilImportStagingLeasePolicyTests` and iOS product XCTest with iOS 15 deployment.
- Physical-device test: select a 100+ MiB local ZIP in File Integrity, immediately navigate back; verify no continuing hash and temporary UUID staged lease cleanup; return and import again.
- Repeat with iCloud provider placeholder, rapid cancellation and second import; verify no duplicate active operation, no stale spinner.
- Test successful A/B file comparison and SHA256 correctness after restart.
- Negative: unsupported provider or revoked grant must show a useful error without leaking a staged file.
- Ensure launch/signature/transport/database regression gates remain green.

**Execution status:** source patch generated against exact main baseline; Apple SDK/XCTest/physical-device tests NOT RUN. No claimed performance results.
