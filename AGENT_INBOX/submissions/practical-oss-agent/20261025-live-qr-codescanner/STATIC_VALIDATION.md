# Verified state (honest boundary)

Base main `501ef814a0a9bea41419fe2d9f48315371b30320`. New local Swift input gate + 4 XCTest methods staged and reproduced in a Linux Swift 6.2.1 temporary SwiftPM package: **4/4 tests passed**. Exact staged source Git blob `a0934fb8e02bfabac7241981bded1b5ee33dcd60` matches locally compiled guard.

The `PATCH.diff` covers 4 exact product paths and 8 hunks. Hunk old and new line counts plus original source context all validated against exact main; patch ends in LF. This is a static patch verification, **not** a successful `git apply --check` claim on an actual checkout.

CodeScanner 2.5.2 upstream public init supports `codeTypes`, `scanMode`, `showViewfinder`, `requiresPhotoOutput`, `shouldVibrateOnSuccess`, callback `Result<ScanResult, ScanError>`. Actual Apple iOS SDK compilation, simulator and physical iPhone7 scanner tests: **NOT RUN**.

No product files or main changed. The only new dependency in the proposal is MIT CodeScanner 2.5.2, conditional on Governor integration.
