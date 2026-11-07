# VLP-CODEX-W1-003 — keyboard-safe numeric drafts

Baseline: 4f1b255; main 2c5b5161027edff097b27fe3323d30f6ca3e430e unchanged.
Scope: dev/veilopoly:VEILOPOLY_DEV/**. No Engine, terms, save, network or asset change.

## Implemented

Replace eight native number-pad fields (auction, trade proposal/counteroffer,
bank amount/periods, stock quantity) with one reusable button-backed editor.
Its separate native sheet has a 12-key grid, clear/backspace/cancel and explicit
Confirm. There is no TextField/first-responder request in this editor, so it
does not summon a system keyboard over the landscape decision controls.

Local input and original bound text are separate: Cancel/swipe dismissal does
not commit; Confirm only writes normalized integer text, never sends a Move.
Order/payment buttons and pure reducer retain current legality, phase, cash,
fee, collateral and balance checks. A changed market price is not frozen by
opening the editor. Existing preflight is recomputed after confirmation.

Money input bound 0...1,000,000,000 matches existing global cash/payload limits;
loan periods 1...12 and shares 1...10,000 match existing engine domains. These
are input bounds, not approval of any loan or investment terms. Empty, signs,
Unicode digits, fractions and overflow cannot confirm. Excess digits do not
overwrite the prior valid draft. No automatic clamping to a financial action.

Horizontal windows use side-by-side summary/keypad; tall windows stack them.
The sheet scrolls at small heights / large text. Key and field labels have
minimum 44pt touch dimensions; Confirm/Cancel targets are inside their button
labels, not just outer padding. Also correct the new browser's Return label
to contain its 88×44pt hit area. Actual device accessibility remains unverified.

## Evidence

- `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 --filter NumericInputDraftTests`
  → 4 tests, 0 failures → PASS (bounds, invalid input, overflow, draft isolation).
- iOS15 ARM64 frontend grammar parse of UI, AssetBrowser, NumericInput,
  StockMarketPanel, BoardScene and guarded scene regression → exit 0 → PASS,
  syntax only, NOT an Apple SDK build.
- Standard build/full-package test results are recorded in CHECKPOINT.
- Supplemental `swift build ... -Xswiftc -warnings-as-errors` → FAIL: six
  pre-existing immutable Codable property warnings, FinanceExpansion.swift:11–16,
  PrintedTabletopProfile. File is byte-identical to baseline. Do not represent
  standard build success as strict-gate success. Warning cleanup remains a
  separate compatibility-reviewed task; no reference rules changed to hide it.

Apple SDK type-check, iOS XCTest and physical device → NOT_RUN. Linux excludes
the SwiftUI implementation. Projection/draft tests are not UI interaction tests.

## Required Apple acceptance

On 844×390, 852×393 and 1180×820, open all eight fields; enter zero/limit/one
over limit, clear/backspace, cancel/swipe, confirm then explicitly place a legal
order. Confirm cancellation keeps old cash/shares/periods, editor confirmation
does not charge/bid, and repeated taps cannot duplicate a reducer action.
Test price tick, actor/phase changes, rotation, VoiceOver, Dynamic Type and
day/night while editing. Verify focus never invokes a keyboard and modal
buttons/underlying ACK lifecycle remain reachable. All these are NOT_RUN here.

NEXT_ONE_TASK: VLP-CODEX-W1-004 — theme consistency audit and scoped palette fix,
preserving Astra/Kimi signed assets; never blindly switch dark panels to black text.
