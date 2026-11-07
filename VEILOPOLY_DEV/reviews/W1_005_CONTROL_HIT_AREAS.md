# VLP-CODEX-W1-005 — control hit-area contract

Before: 06a659a; main 2c5b5161027edff097b27fe3323d30f6ca3e430e; #168 lane only.

Source defects: animation-skip caption/padding had no minimum height; stock
portfolio toggle was a small label and holdings rows could be <44pt. Five
quantity shortcuts shared one row: the narrow 292pt drawer has ~212pt remaining
after nested paddings, less than the 240pt required by 5×44pt plus spacing.

Fix: common 44pt minimum, applied INSIDE actual button labels/content shapes;
portfolio toggle exposes expanded state to VoiceOver. Quantity shortcuts use
adaptive columns so they wrap rather than shrink. No transparent overlay across
neighbor controls, no enlarged board-cell overlaps, no new gesture, rule or ACK.

Executed:
- `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 --filter 'LandscapeLayoutTests|RenderCommandAckGateTests|StockTerminalStateTests'`
  → 21 tests / 0 failures → PASS, portable contracts only.
- Full package → Linux Swift 6.2.1, 249 / 0 failures, 42.572s → PASS.
- iOS15 ARM64 frontend parse UI/StockMarketPanel → exit 0 → PASS (grammar only).
- `git diff --check` → no whitespace errors → PASS.

NOT_RUN: Apple SDK build/XCTest, actual frame/hit testing, clipped/offscreen
targets, Dynamic Type, VoiceOver, scrolling and 844×390 / 852×393 / 1180×820.
The new portable test proves minimum constants and the narrow-width arithmetic,
not SwiftUI's rendered targets. Full HUD dragging/clamping remains unfinished.

NEXT_ONE_TASK: VLP-CODEX-W2-001 — investigate malformed pendingPurchase indices:
buyProperty directly indexes board[pendingPurchase], and startAuction can carry
the same invalid index into later settlement. Prioritize possible crash over
additional visual polish; reproduce before changing Engine behavior.
