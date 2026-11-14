# VeilLink 29.1 · Build 67 — ECLIPSE / Model-Free Integration

## Release scope
- ECLIPSE R14 native Gomoku policy: trained 48-tree move ordering, bounded native PVS, current R4/R6/R8 mandatory tactical guards, optional disabled-by-default R12 horizon and R13 incremental index.
- Seven Gomoku difficulties: 轻松、均衡、进阶、宗师、棋圣 2×、传奇 4×、天元 6×. Multipliers describe **maximum search time budget relative to Master**, NOT demonstrated 2×/4×/6× chess strength or Elo.
- Native optional actual search branch visualization, VeilLink-native themes, and per-match history. No fabricated engine telemetry.
- Chinese chess retains four selectable difficulties and existing saved games continue to restore.
- Portrait Veilopoly split-screen workspace, dynamic dashboard/widgets and orientation-respecting presentation; combined with P0 touch repairs rather than overwriting them.
- Inbox repairs: black-box log integrity and advisory health-state semantics, BLE reconnect intent on app foreground, native chat inline glyph and composer options, and Veilopoly touch/numeric input repairs.
- Removed the experimental 29,203,168-byte Vertex GGUF plus related Qwen/llama native language-model dependencies. Keep **model-free VeilTalk Lite**, BLE/transport and game A10 assets unchanged. No `.gguf` or `llama.framework` may be packaged.
- Existing V29 Veilopoly live feature, document/camera/game routes, and earlier sources retained.

## Verification and limitations
The signed binary is not produced by CI: release is an **unsigned IPA** requiring the owner's permitted signing/install method.
Passing CI simulator tests and a clean packaged-IPA manifest does **not** establish iPhone/iPad physical acceptance. BLE two-device radio performance, app touch performance, session restoration, and seven-tier long-game thermal data require actual-device tests.
Search-time multipliers are NOT chess-strength multipliers; ELO/paired-tournament strength is not yet certified.
The A10 Ultra M5 shadow guard remains unchanged. R12 and R13 experimental search toggles remain OFF by default.
This release must only be published if GitHub full iOS CI, native XCTest, Release iPhoneOS build, and explicit IPA contents/digest verification all pass.
