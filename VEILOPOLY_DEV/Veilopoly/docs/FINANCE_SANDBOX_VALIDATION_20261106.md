# Veilopoly isolated banking reference prototype · validation (2026-11-06)

**Source snapshot:** `dev/veilopoly` source plus new finance/policy modules; early import `9d3b4be3ea1e15ad6387a59cf7e9227412d621db`, follow-up safety pass `5a2d540cdc661f223e898a50adc188a9f6872f14`.

## Implemented artifacts
- `Sources/VeilopolyEngine/FinanceExpansion.swift`: `FinancialSandboxState`, `FinanceSandbox.apply`, bank deposits, loan quote & repayment, virtual managed/venture/stocks simulation on explicitly provided outcome tables, and no-stake dice challenge. Pure Swift, deterministic, `seededRNG` only.
- `Sources/VeilopolyEngine/PrintedTabletopReference.swift`: optional start reward semantics, 8-star award/reset/leader logic and injected elapsed-minutes cash leaders. It is NOT installed as active GameState rules.
- `Tests/VeilopolyEngineTests/FinanceExpansionTests.swift`: 7 cases.
- `Tests/VeilopolyEngineTests/PrintedTabletopReferenceTests.swift`: 4 cases.
- `docs/OWNER_FINANCE_AND_TABLETOP_RULES_20261106.md`: source-based paraphrase, disagreements and pending owner interpretations.
- `docs/KIMI_FINANCE_HUD_REQUEST_20261106.md`: Kimi's visual-only financial overlay work, after K2.

## Verification
- Swift 6.2.1 / Linux `swift build --jobs 2`: **PASS**.
- Swift 6.2.1 / Linux `swift test --jobs 2 --filter 'FinanceExpansionTests|PrintedTabletopReferenceTests'`: **11 passed / 0 failed**.
- Swift 6.2.1 / Linux `swift test --jobs 2 --skip 'AutoplayTests|LongSimTests'`: **53 passed / 0 failed**.
- Swift 6.2.1 / Linux `swift test --jobs 2` full suite: **55 passed / 0 failed**, including 500-seed bounded AI smoke and 20-seed long simulation. Short 500-seed cases are NOT 500 naturally completed games.
- SHA / Git blob crosscheck: all six new source/test/doc files on branch matched local tested file bytes.
- No iOS 16 Apple SDK, in-game visual integration, or GameTransport end-to-end verification has been done.

### Coverage — separate local instrumented run

- `swift test --enable-code-coverage --jobs 2 --skip 'AutoplayTests|LongSimTests'`: 53/53 PASS.
- LLVM line coverage for all six `Sources/VeilopolyEngine` files: **941 of 995 lines = 94.57%**, above the initial 90% engine goal.
- File breakdown: `Board.swift` 71/71, `FinanceExpansion.swift` 204/206, `Models.swift` 78/80, `PrintedTabletopReference.swift` 44/44, `Rules.swift` 495/545, `SampleCards.swift` 49/49.
- This is a **local Linux instrumented** result, not GitHub CI and not Apple iOS SDK; long AI pressure cases were included only in the separate 55-case ordinary test run.

## Deliberate gates

1. Classic game still uses original salary, housing, GameState and stateHash; enabling printed profile needs explicit owner approval and a versioned migration.
2. Savings yields and duration are `nil` by default, and deposit attempts return `termsAwaitOwnerRuling`. Sample yields in tests are fixtures only.
3. Finance risk products require an approved 6-outcome table; no positive payout figures are assumed from ambiguous handwriting.
4. 4+ eligible lots have no specified loan cap and are blocked rather than assigned the 3-lot cap.
5. No cash gambling or real-value staking mechanism is provided.
6. P5 host app integration, BLE/Protocol4/VLGM1, SQLite V8, release workflow, signing and IPA remain untouched.
