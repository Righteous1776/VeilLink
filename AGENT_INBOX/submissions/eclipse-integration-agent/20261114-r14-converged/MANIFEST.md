# [AGENT-DROP] ECLIPSE R14 — governed consolidated native engine / real trace / UI

agent_id: eclipse-integration-agent
task_id: 20261114-r14-converged
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
mode: INBOX_ONLY
submission_path: AGENT_INBOX/submissions/eclipse-integration-agent/20261114-r14-converged/
status: SOURCE_CONVERGED_AND_PATCH_PREFLIGHT_PASS; IOS_BUILD_NOT_RUN; NOT_MERGED

## Deliverables in this GitHub Inbox
- `PATCH.diff`: **one** 294,010-character product patch, 21 unique product/test files (4 existing modifications + 17 new), 46 structurally validated hunks.
- `PATCH_CORE.diff`: native trained engine, controller, two R12/R13 helpers, 48-tree frozen trained model, 3 proposed XCTest files.
- `PATCH_UI.diff`: existing VeilLink-native ECLIPSE appearance, durable every-match history, R11 terminal, R12 genuine board path and opt-in switch.
- `FILES/Native/GomokuBot.swift` and `FILES/Controller/LocalAIGameController.swift`: exact merged product preimages; native R4/R6/R8 mandatory tactics, trained PVS and true 1–3-ply trace under **ONE final move arbiter**.
- `FILES/Native/VeilGomokuUnifiedSearch.swift`: merged Codex PR #209 source + exactly replayed #213 horizon + exactly replayed #214 incremental index, both flags OFF, plus actual observed branch API.
- `FILES/Native/EclipseTrainedOrdering.swift`: exact byte-for-byte frozen PR #209 code; blob SHA `4e73cc1910820324487d9350194cfb5562a8439f` and reported model SHA-256 `f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe`.
- `FILES/Native/EclipseHorizonQuiescenceR12.swift`: identical source to #213; blob `0eb6e94e37052a19cc2b96bc1a82463f6fadfc22`.
- `FILES/Native/EclipseIncrementalThreatIndexR13.swift`: identical source to #214; blob `a8241383c28422ac75542caaa7b5f684c01c39bb`.
- `FILES/UI/`: four game view/card files and eight sourced ECLIPSE UI helpers from canonical PR #208. All source code, no binary asset dependency.
- `FILES/Tests/`: three proposed XCTest modules, including new `EclipseR14UnifiedTests.swift` (unexecuted).

## Validated in this work
1. Codex base -> independent PR #213 overlay patch replay EXACTLY equals Agent's staged R12 source (2 hunks).
2. Codex base -> independent PR #214 overlay patch replay EXACTLY equals Agent's staged R13 source (6 hunks).
3. R12 and R13 flags rebased into one kernel (R13 adds 5 nonoverlapping remaining hunks), plus truthful optional 1/2/3-ply branch callback.
4. All 4 main file changes in final PATCH.diff applied **in memory** with exact line-based context against actual main; result equal byte-for-byte to staged product files.
5. All 17 new-file sections in per-category patches match staged source byte-for-byte.
6. 21 paths unique; 46 final patch hunks matched declared old/new line counts.
7. Frozen trained source and R12/R13 helpers preserve upstream Git blob SHAs.

## NOT validated
- **Actual full checkout `git apply --check`, Xcode, XCTest, Swift concurrency typecheck, runtime end-to-end source wiring, real-device power/thermal or regression tournaments**.
- Those explicit gates are REQUIRED before Governor integration and any IPA.
- This PR does not merge main, start workflows, change version, remove old MIT notices or release an IPA.
