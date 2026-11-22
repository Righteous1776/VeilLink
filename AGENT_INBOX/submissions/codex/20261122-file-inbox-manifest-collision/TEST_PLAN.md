# Verification

## Patch replay

Passed on main 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32. Checked git apply against the checkout, applied to isolated copies of both exact source files with whitespace errors enabled and checked reverse application.

## Integration acceptance

Run VeilFileInboxTests including testManifestNameVariantsPreserveImportedBytesAfterStagingCleanup, then VeilUnifiedImportEndToEndTests on the iOS simulator. Cover ordinary names, repeat imports, oversized content, staging cleanup and post-import tampering with the existing suite. On an iOS Files provider, import record.json, reopen the inbox after relaunch, inspect the displayed name, then share and compare the bytes with the original. Run the normal integration test suite on the accepted commit.
