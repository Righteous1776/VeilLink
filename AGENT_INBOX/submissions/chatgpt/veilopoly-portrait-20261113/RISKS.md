# Boundaries, overlap and risk

- INBOX_ONLY: candidate Swift code is staged under `AGENT_INBOX/submissions/chatgpt/veilopoly-portrait-20261113/FILES/` plus `PATCH.diff`; not integrated in `dev/veilopoly`, `main` or an IPA. No iOS CI/XCTest run has been claimed.
- The new UI.swift change overlaps existing unmerged PR #184 on the same file; **do not replace PR #184 UI.swift** or reset its branch. Arbitrator must rebase and combine selection/skip/auction changes with new portrait layout. This is an intentional separate submission; no implicit merge permission.
- Host orientation mask and UI lifecycle can still restrict portrait/landscape; package cannot override host Info.plist without separate authorized product change. Dynamic Type and safe-area appearance must be checked on real iPhone7.
- The whole 40-cell board on a small portrait screen has compact per-tile visual targets. Existing BoardScene hit-boxes and future P2 gestures must be evaluated; no unsupported 44pt-per-tile guarantee.
- New `@AppStorage` preference is **UI only**, not GameState, SQLite schema or save migration; changing raw widget IDs in future may require preference migration.
- Reflected bank rates apply only when canonical ledger supplies them. Market does NOT advance during AI turn under existing engine/UI ticker gating; widgets must not mislabel stale prices as new ticks.
- `VeilopolyAssetBrowser` is snapshot-style and may not update while a sheet is open (game value captured at presentation); regression acceptance should test read-only current values after reopen.
- Real out-of-turn trades require deterministic engine turn policy and host/guest sequence safety. No bypass of `Move` actor/phase checks and no local speculative money changes.
- No RenderCommandAckGate/Engine/AI/Net/Wire/identity/Astra asset edits, no workflow dispatch, no self-merge or unsigned IPA build.
