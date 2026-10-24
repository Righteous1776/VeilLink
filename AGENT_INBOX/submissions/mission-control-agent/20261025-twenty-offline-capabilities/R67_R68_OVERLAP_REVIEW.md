# Governor conflict review — two Mission Control R1 submissions (2026-10-25)

## Collision

- **PR #67** `agent-drop/mission-control-20-offline-features-20261025`: contract-only GitHub Inbox submission, plus a user-delivered *complete* local ZIP `VeilLink_MissionControl_20Features_R1_20261025.zip` (SHA-256 `61b4bb8cdb6070b2d5c47100bff9a0f3c1ebba67471b57db6174e62aa6250a3d`). Its actual Swift sources are **not** part of PR #67 itself. Feature style: 20 user-input operators with parsing/validation, iOS15 SwiftUI editor and XCTest. Files have the proposed same names `VeilMissionControlEngine.swift`, `VeilMissionControlView.swift`, `VeilMissionControlEngineTests.swift`.
- **PR #68** `agent-drop/mission-control-20-20261025`: 20 data-snapshot diagnostic algorithms, 3 simulated scenario presets, SwiftUI disclosure screen and proposed XCTest source **fully staged in GitHub** under this own Inbox `FILES/`, plus ToolCenter `PATCH.diff`. Same three desired file names as PR #67, different APIs and semantics.

**Both cannot be applied verbatim**. They conflict on *all three desired added product paths*, including `VeilMissionControlEngine` type identity. There is also a ToolCenter navigation interface requirement.

## Independent ZIP verification

The on-disk user artifact from PR #67 was found in this conversation's authorized workspace; archive SHA-256 matches the PR #67 declared hash. Its Foundation engine was independently compiled under Linux Swift 6.2.1 (`swiftc -parse-as-library -emit-module -enable-testing`); bundled XCTest candidate successfully `swiftc -typecheck`-ed as a module consumer. This does **not** establish iOS/SwiftUI compilation or physical iPhone performance.

## Recommendation: preserve both contracts; integrate one deliberately

For an **immediately usable offline toolbox**, PR #67's interactive user-editable operators are a better R1 front-end because each of twenty tools can analyze actual user-pasted data. Its real source must first be imported from the verified ZIP as a separate owner/Governor-controlled integration action — merging PR #67 itself would merge only a contract.

PR #68 has complementary value as a **typed read-only device health dashboard** (e.g., missing database key fail-closed interpretation, Mesh alternate route, link health, incident triage, battery/thermal) and all 20 implementations are GitHub-auditable. To keep it, rename its engine/view/tests as `VeilMissionAdvisorEngine`, `VeilMissionAdvisorView`, etc., in a *new* revision after Governor selection, not by silently overwriting PR #67.

Do **not** concatenate both candidates, overwrite another agent's files, or count the combined feature total as 40 shipped functions.

## Integration hard gates

1. Finish urgent P0 proposals #64/#65/#66 and preserve iPhone7 storage/Keychain.
2. Governor select one source of truth for R1 (recommend #67 ZIP + real ToolCenter link), then stage code in a controlled source branch.
3. Run exact-head macOS iOS15 compile, complete XCTest and iPhone7 interaction tests. Neither PR has passed an iOS SDK build.
4. Real-time BLE/Keychain/SQLite adapters are separate protected work: no automatic packet/identity/storage changes from a user-entered simulation.
5. No `workflow_dispatch`, IPA packaging or release as part of this review.

## Independent native XCTest run (Linux only)

The verified PR #67 ZIP was expanded to an isolated SwiftPM package in the analysis workspace (Foundation engine and bundled test file only; no source tree mutation). `swift test -j 2` under Linux Swift 6.2.1: **7 tests executed, 0 failures**; the broad test iterated over all **20** declared feature examples. This validates the Foundation algorithms and bundled test file on Linux, **not** the SwiftUI view or iOS 15 physical app. Mac/iOS validation is still required.
