# VeilLink 29.1 · Build 67 — ECLIPSE Gomoku / Model-Free Core

## Included in this release candidate

- ECLIPSE native Gomoku unified search: preserve the existing R4/R6/R8 defensive rules, bring in a frozen 48-tree trained ordering model, a single native search arbiter and native post-move legality checks.
- **Seven Gomoku difficulty choices**: 轻松 / 均衡 / 进阶 / 宗师 / 棋圣 · 2× / 传奇 · 4× / 天元 · 6×. The last three use approximately 2×, 4× and 6× the *master compute-time budget*, **not** proven 2×/4×/6× stronger Elo or gameplay skill. The Chinese-chess menu remains four levels.
- Optional R12 quiescence and R13 incremental threat index are both **OFF by default** pending device and fresh-match validation; real-search branch tracing is separately user-opt-in and session-bound. Historical match archive and training sequences are preserved.
- Blackbox ZIP inventory/write-loss and unevaluated A9 reporting repairs, foreground BLE wanted-peer recovery with reconnect backoff protection, and app-level inline flag rendering/opt-in chat composer fixes are included as proposed regressions to verify.
- Veilopoly touch repairs (#184) and 50/50 portrait-workspace layout (#188) are jointly integrated in one UI.swift implementation, retaining board selection, read-only finance panel and original action/ACK semantics. Touch/geometry require real hardware acceptance.
- Additive ZeoStudio governance and retained Inbox proposals remain separate from runtime authority; no schema, crypto identity or Wire4 changes intended.

## Explicit model exclusion

- **The 29,203,168-byte experimental Vertex-0.6-35M-Instruct-Q4_K_M.gguf is NOT bundled.**
- Native Vertex/Qwen/llama language inference and its experimental model code are removed from the active tree. Standard `project.yml` is used for all iOS builds; `--experimental-vertex` is not used.
- The standalone model-free VeilTalk Lite interface remains available. Existing A10 game/training assets are not deleted. The 48-tree Gomoku ranking logic is compact source code, not the removed 30 MB language model.
- Build verifier must reject any `*.gguf` or `llama.framework` inside the final IPA, check digest/manifests and enforce the existing app payload budget.

## Verification and limitations

Publication is conditional on GitHub iOS CI + XCTest, unsigned iPhoneOS candidate build, and the Core carrier/size manifest integrity gate passing on this *exact source version*. No release is authorized from a merely staged Inbox drop.

Physical two-phone BLE connection recovery, iPhone7/iPad landscape/portrait touch accuracy, fairness of match search-visualization, and measured Gomoku strength/energy/thermals require real-device testing. A clean independent 5,000-game equal-budget match tournament has not yet been performed; never claim sixfold chess strength.

The IPA is **unsigned** and requires a compatible owner signing/install method. Existing saved-game compatibility must be reviewed before declaring production acceptance.
