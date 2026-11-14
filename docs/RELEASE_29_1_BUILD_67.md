# VeilLink 29.1 · Build 67 — ECLIPSE Gomoku / Model-free Core

Incremental ECLIPSE R14 integration on top of V29.0 Build 66; all existing communication, Veilopoly, storage, identity and saved-game features are intentionally retained.

## Gomoku
- Unified native PVS with frozen trained 48-tree Swift ordering policy; no NPZ model/weights are added.
- Original R4/R6/R8 mandatory tactics and R6 formation/learning priority are preserved in the selected move arbiter.
- Seven Gomoku tiers: original four persisted values plus 棋圣 2× / 传奇 4× / 天元 6×, with larger native ECLIPSE search-time budgets and XCTest coverage. Xiangqi remains four-tier. Budget multipliers are NOT measured Elo, win-rate or literal playing-strength multipliers.
- Experimental R12 horizon and R13 exact incremental threat acceleration remain OFF by default pending controlled A/B tests.
- Optional genuine per-session board search trace (OFF by default), VeilLink-theme compute console, and per-match game history/archive. Existing JS assets and notices retained for provenance and rollback.

## No 30 MB model in this edition
- Vertex-0.6-35M-Instruct-Q4_K_M.gguf (29,203,168 bytes) and llama.framework are NOT packaged. Experimental on-device Vertex35M LingCore chat is unavailable in this IPA.
- iOS CI and release use standard project.yml. Mandatory core verifier rejects every GGUF/llama.framework, brain.npz or weights.npz in the app and IPA.
- No signing-secret, protocol, identity, database schema, or A9/A10/A13 authority changes.

## Acceptance / limitations
Publication is gated on the exact integration head passing full macOS Xcode/iOS CI and XCTest, unsigned iPhoneOS compilation, IPA integrity and resource exclusion checks. Prior isolated Linux source assertions do NOT establish shipped-product acceptance. New equal-budget, color-swapped independent Gomoku matches, iPhone/iPad thermal testing, long-run search cancellation/archive migration and real two-phone communication acceptance remain NOT_RUN unless evidenced elsewhere.

IPA is unsigned; owner-side compatible signing/installation is required. Do not describe a PR candidate as a released artifact.
