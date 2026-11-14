# R14 Risks / Governor Review

- **Large integration collision:** #209 trained `GomokuBot` / controller and #208 ECLIPSE touch the same old files. This candidate resolves one AI-selection conflict, but formal human-reviewed merge and Xcode concurrency audit remain blocking.
- **Experimental R12/R13 not proven together:** both implementations are present, with flags disabled; code overlap merged at source level only. No demonstrated fresh merged-engine matches or mobile thermals. Do not infer full-engine 14–18x speedup from narrow R13 microbenchmark.
- **No iOS compile:** Linux Swift 6 testing by individual Agents is not a substitute for app XCTest with `SWIFT_VERSION=5.9` and `SWIFT_STRICT_CONCURRENCY=complete`.
- **Wall-clock observer cost:** optional explored path observation capped at ~20Hz before delegating to thread-safe store. Native depth/node updates are actor-gated by original sessionID, moveCount and game status, but concurrency testing still required.
- **Real spatial paths may convey strategy:** opt-in default OFF; only available while AI actually calculates, cleared on game over/cancel. It is *not* zero-information and should be hidden during competitive games.
- **Training provenance:** frozen 48-tree model from #209 copied byte-identically; no new 1.85M-row training or novel cross-PR win-rate evidence. Do not advertise millions of played games or 6x strength.
- **Legacy engine remains shipped on disk:** controller no longer selects JavaScriptCore, but JS resources/project.yml and any third-party notices remain until Apple build, equivalent game behavior and legal review permit removal. Old preference ignored, not deleted.
- **Source panel truthful display:** decorative black `vis.*` rows are not real inference code; actual measured tree summaries are separate. Human review of exact UI needed.
- **Submission governance:** changes only in own Inbox subtree, not in product/main. No live lane grant, no release/IPA/workflow dispatch or merge authority. Governor must resolve sibling overlapping drafts and run CI gates.
