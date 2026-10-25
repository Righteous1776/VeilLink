# Verification plan / evidence

## Pass: actually run

- R4 local source package, Swift 6.2.1 Linux: **60 XCTest / 0 failures** (R3 35 + E191 11 + numerical/historical maintenance 8 + feature admission gate 6).
- 200 IDs unique, E01–E190 identity preserved, E191–E200 exactly ten; 610 unique stage brief IDs; 200 * seven documented subsystem contracts.
- E191 4 x 16 chart generated from seed, checked against authored JSON content pack; invalid lane/time protected; deterministic replay and Codable encode/decode pass.
- Empty/out-of-range chunks safe, legacy R3 JSON snapshot decode pass, 2048 cap works, orbital invalid physics rejected, city economy nonnegative.
- Local full add-only `PATCH.diff`: git apply --check (isolated empty git scratch) PASS; SwiftUI candidate *syntax parse* only, not Apple SDK.
- GitHub patch stages admission gate source and six test methods verbatim; other maintenance engines exist only in local R4 ZIP.

## Pending (mandatory for feature integration)

- Exact-main integration-branch product path review, iOS XcodeGen membership and SwiftUI typecheck, XCTest full App inventory, iOS15.8.3 iPhone7 legal/dark/light/touch input, storage and Keychain signer continuity, resource/performance profiling, regression across chat and games.
- No CI workflow dispatch or unsigned IPA from this task.
