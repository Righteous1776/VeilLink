# Owner eight-item triage and recovery paths

| # | Requested change | Status in this Inbox | Next integration boundary |
|---|---|---|---|
| 1 | Files import in 7 workflows | Proposed real shared source and seven-file patch | Apple SDK, iCloud/Files, real device, restore rollback |
| 2 | Gomoku/Xiangqi physically separated unlimited-sized persisted training | NOT DONE | Separate per-game DBs, explicit migration, per-game export/reset and storage exhaustion policy |
| 3 | Predict full move sequences/formations, learn from losses and interruptions | NOT DONE | Sequence/formation feature extraction, counterfactual legal move selection, "阵法预判" UI, replay tests |
| 4 | A10-only displays current A10 live data in Settings/Owner | Proposed patch | Mode/epoch and simulator/device replay tests |
| 5 | Toolkit reclassification, background governance for diagnostics | NOT DONE | Routing audit and privacy-first status model; do not hide functionality without replacement |
| 6 | Restore rhythm/lattice/story navigation | Proposed patch | iOS15 functional navigation tests |
| 7 | Galgame restore entrance, R5 binary missing | Missing-resource status entrance proposed | Owner R5 ZIP hash 068ba55b..., verified source/vendor restore and WebKit/iPhone7 validation |
| 8 | Restore 三国兵器 large 48×27 map, remove small arena | Asset and existing multiplayer V2 entry located, NOT integrated into solo lobby | Build offline V2 campaign/session bridge; do not break legacy wire compatibility |

Current source of large-map truth: `VeilLink/Resources/Tactical/guandu_large_map_v2_48x27.json`, `VeilLink/Core/TacticalV2/TacticalLargeMapLoaderV2.swift`, `VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift`, `VeilLink/UI/TacticalV2/TacticalV2LaunchGateView.swift` (the latter currently accepts a conversation/session and negotiates capabilities).

Monogatari official 2.8.0 owner ZIP was verified historically by game agent, but the full R5 package is **not currently available** to this handoff. Audit `PR #85` and its `R5_ADDENDUM.md`; don't invent vendor resources or include missing binary in main.
