# V10 risks and overlap

- Draft PR #199 from fellow Agent already proposes V9. Must not rewrite, self-merge or silently cherry-pick overlapping GomokuBot changes. Only two additive new-file sources proposed.
- V10 proves a restricted double-open-three -> all-defense -> double-five fork family; it is NOT full VCT and not a measured playing strength improvement.
- Proof can be expensive if run on all roots; recommendation: only advanced extended tiers with bounded <=120ms proof slice and <=6000 checks, subject to real device benchmarks.
- Current V10 code relies on existing native `GomokuCounterForkR4.createsForcedDoubleWin`; behavior depends on the unrestricted 15x15 Gomoku rules; not Renju forbidden-hand legality.
- Local source-stub and oracle assertions do not replace actual production Swift/iOS XCTest or frozen full-game verification.
- No raw private training set available or committed; previous 212-case results NOT rerun in this task.
- ECLIPSE fair-play R8 forbids revealing coordinate root/branch/PV or tactical hints while the match remains in progress. Certified moves remain private until chosen and played.
- Legacy MIT JS source/license unchanged. Independent V10 module does not create permission to erase attribution from any remaining licensed adaptation.
- No direct product source edits, workflow dispatch, main merge, release, IPA, training DB or version changes in this PR.
