# R5 Testing

### Completed locally (owner ZIP)
- Linux Swift 6.2.1 -swift-version 6 -warnings-as-errors -O: kernel and bridge compile.
- 6 native smoke checks, 4 bridge behavior checks.
- 212/212 actual R2 fork-risk instances; 1696/1696 with 8 rotations/mirrors; these are safety-label proxies, not real matches.
- Basic 30-position timing benchmark: mean 82ms on Linux only.
- Full owner patch passes git apply --check on synthetic exact known source snippets, not on full repository checkout.

### Required, NOT completed
- Obtain owner ZIP and run full main git apply --check before integration.
- Actual Apple SDK build, XCTest, SwiftUI actor concurrency and cancellation.
- Equal-budget native-vs-old engine games, legal/tactical validation, score calibration, thermal and battery measurements on target devices.
- History storage and backup migration/safety; iOS15 compatibility policy at integration.
- Full VCT defensive proof and legacy resource removal after verified parity.
