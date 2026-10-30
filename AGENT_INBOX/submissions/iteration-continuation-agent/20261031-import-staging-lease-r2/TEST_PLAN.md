# Test evidence and mandatory gates

Executed: Linux Swift 6.2.1, SwiftPM tools 5.9, swift test --jobs 2: **7 XCTest PASS, 0 failures**. Cases: UUID lease deletion; look-alike/non-UUID refusal; symlink refusal; fresh retention; expired removal; max-removals budget. Local harness uses @testable import VeilLinkStagingGuard; the staged test imports the actual app target VeilLink instead.

Pending: apply-check against base main with absent target files, XcodeGen iOS 15 simulator/device compile, full app XCTest, physical iPhone 7 / iOS 15.8.x, iCloud and third-party Files Provider, 200 MiB backup cancellation and locked-device/protected-data behavior. Verify no active long restore loses its staged copy when sweep runs; repeat P0 consent/touch, old encrypted backup rollback, A10. Existing 763 tests refer to V27 baseline only and do not validate this candidate. NO IPA or release.

R2 amendment (executed): activeLeaseIDs cannot be omitted; a seventh XCTest proves a live UUID lease is retained even after TTL. Exact app-target iOS/XCTest remains pending.
