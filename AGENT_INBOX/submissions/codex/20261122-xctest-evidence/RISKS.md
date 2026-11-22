# Integration considerations

The parser expects the standard English XCTest root completion and immediate totals lines. Logs with worker-only or interleaved output that lacks this evidence can return unverified. A missing skipped-count clause contributes zero reported skips. Older reporters that omit skips cannot establish the actual number skipped from totals alone. The aggregate pass criterion does not certify any particular test-target inventory.

Current consumers keep the existing fields and status vocabulary. latest_reported_skipped is additive. An incomplete final root completion yields null counts instead of unrelated nested counts.

PR #106 originally proposed these parser and test files. The inspected recent integration heads #243, #245 and #246 carry the main versions. Verify the scripts on the target branch before applying. The archived Build 68 CI artifact could not be replayed here. A real macOS fixture and Linux XCTest executions were used locally. The patched collector still needs verification in the project's Apple CI environment.
