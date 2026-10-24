# RareLab R1 — exact-source provenance + integration review
Base main: `501ef814a0a9bea41419fe2d9f48315371b30320`
Draft PR: https://github.com/Righteous1776/VeilLink/pull/70
Full original owner-deliverable ZIP: `VeilLink_RareLab_40Features_R1_20261025.zip`
ZIP SHA256: `ffbd1865e39594fffc7d6134f8ac9856888baa03b446cfefe975bc20aea17117`

## Reproducibility repair

The first GitHub Files upload stripped the final LF byte from every original text file, including `PATCH.diff`. In a local isolated Git test, the LF-stripped unified diff failed `git apply --check` with **corrupt patch at line 10**, while the original ZIP version passed. Therefore we restored the exact original LF to all eleven staged files. Each of the eleven GitHub Git-blob SHA-1 values now **matches the same original ZIP member byte-for-byte** (Git object preimage format `blob <byte-count>\0<content>`). No actual product files were changed.

## Verification performed

- Swift 6.2.1 Foundation engine on Linux: SwiftPM XCTest **8 tests passed, zero failed**; tests include one sweep executing each of forty catalog entries and a repeat deterministic sweep.
- SwiftUI proposed view: Swift parser syntax PASS, **not** SwiftUI/iOS SDK type-check.
- ToolCenter additive diff: all three exact old-context lines match main `ToolCenterView.swift` starting at line 68, three inserted new lines, hunk header counts valid. The full-ZIP patch passes isolated `git apply --check` on a same-context mock working tree, **not on a full GitHub product checkout**.
- ZIP archive CRC test PASS, eleven files, three Swift source files.
- No iOS SDK simulator build, no iPhone7 device tests, no official full-product XCTest and no IPA Actions were started.

## Integration conflicts and sequencing

- `VeilRareLabEngine.swift`, `VeilRareLabView.swift`, and tests use unique type names; do not rename/replace Mission Control PR #67/#68 sources.
- `VeilLink/UI/ToolCenterView.swift` is shared UI integration surface; PR #67/#68 and other agents propose separate cards. Integrate via manual hunk replay, not blind patch merging.
- PR #69 is the separately developed Feature Century 100-feature *planning* specification, not 100 implemented features. Avoid claiming shipped totals or assigning overlapping catalog IDs without Governor reconciliation.
- PR #64/#65/#66 iPhone7 touch/startup P0 remains a blocker before new UI is promoted. Preserve old SQLite and Keychain, do not start signing/build/release or change main.

## Physical and performance gates

Measure all 40 sample executions on iPhone7 iOS15.8.3 (A10) with touch latency, memory and battery/thermal constraints. Pay particular attention to `Mesh` articulation/bridge enumeration and `faultCoincidence` time-window comparison: both can perform combinational work and are currently called synchronously from a SwiftUI button action. Do not approve automatic scheduling or live-telemetry looping without an off-main executor and bounded benchmarks. For now, they are explicit manual-input only.
