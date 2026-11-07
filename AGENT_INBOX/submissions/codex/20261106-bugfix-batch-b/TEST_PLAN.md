# Test Plan

The owner waived physical-device testing as a prerequisite for continued coding. That does not convert Apple SDK, simulator, or device checks into pass.

## Static checks

- `git diff --check` → no whitespace errors → **PASS**
- `git diff ... | git apply --check --whitespace=error-all -` against `ccafebab147e069fbabfff579dbf323b0d54f191` → applies cleanly → **PASS**
- `git diff --diff-filter=D --name-only` → no deleted files → **PASS**
- Tree-sitter parse of six changed Swift files → six parse successfully → **PASS**
- Whole-tree parser → seven parser failures reproduced unchanged on clean Build64 (`PhotoLibrarySaver`, onboarding controller, tactical layers, arcade scene, stress controller, DeepTelemetry, and an existing Inbox FILES candidate) → **FAIL (baseline/tooling limitation, not introduced by this patch)**

## Unit tests

- Swift 6.2.1 compiled policy harness with `-swift-version 5 -strict-concurrency=complete` → BLE/unknown route = 800KiB; LAN/Relay = existing 3MB; output `BATCH_B_IMAGE_POLICY_PASS` → **PASS**
- `MediaTransferPolicyTests.testImagePayloadPolicyUsesConservativeBudgetForBLEAndUnknownRoutes` → authored in patch; Apple XCTest not available → **NOT_RUN**
- Image transcoding at 800KiB with JPEG/HEIC/PNG fixtures → requires Apple ImageIO/CoreGraphics environment and fixtures → **NOT_RUN**

## Integration and negative cases

- Unknown route followed by BLE delivery → selected cap remains 800KiB → policy harness pass; full session delivery → **NOT_RUN**
- LAN/Relay route → maximum remains 3MB → policy harness pass; full session delivery → **NOT_RUN**
- 801KiB+ image that cannot be reduced within the selected cap → user receives current-route size error and no `sendImage` call occurs → **NOT_RUN Apple UI test**
- `OSSignposter` intervals visible in Instruments → no macOS/Xcode Instruments environment → **NOT_RUN**

## Regression invariants

- Wire v4 frame format and 3MB `WireProtocol.maximumImageBytes` → unchanged by diff review → **PASS**
- Relay pairing, SQLite schema, M5 shadow, production-cutover, versions, workflows, and releases → unchanged by diff review → **PASS**
- Device/simulator results → not claimed → **NOT_RUN**
