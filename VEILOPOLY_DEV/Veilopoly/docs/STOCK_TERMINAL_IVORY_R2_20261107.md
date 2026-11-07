# Veilopoly Stock Terminal R2 — Ivy classical unification + durable fills

Task: VL-VEILOPOLY-STOCK-R2-20261107. Baseline `ce94f4ed72bb39966ff8feb216e10e965eda5b8b`; lane `dev/veilopoly` only.

## Root cause and changes

1. Previous `GameSessionModel.stockExecutions` was only a 40-entry in-memory array; the simulated market, positions and game cash persisted, but last trade fills disappeared after app relaunch. New `VeilopolyStockExecutionRecord` is encoded as optional `stockReceipts` in the **same two-slot sealed GameState checkpoint**. A stockBuy/stockSell reducer move produces an authoritative Effect, the UI maps it to a receipt, and the normal post-reducer checkpoint writes market, cash, sequence and receipts together. On restore the UI reconstructs the eight visible execution-history rows from the latest 40 recorded fills. No extra filesystem writer, no second game state or asynchronous receipt write.
2. `VeilopolySavedGame` now explicitly handles Codable to **omit the optional key when nil**; this preserves the exact pre-upgrade sorted-key JSON checksum of legacy A/B snapshots. Older archives have no execution history, which is shown as empty rather than guessed. Checkpoints continue to verify the entire sealed payload.
3. Receipts are bounded to 40, unique and newest-first, tied to real committed `Move.stockBuy/.stockSell` IDs, player, ticker and share count. Invented or stale receipts are rejected as invalid save states. New-game Reset clears receipts before saving, preventing resurrected fills from a previous game.
4. Fixed literal `T+(market.tick)` in Codex's terminal header to actual Swift interpolation `T+\(market.tick)`.
5. The full dark-navy stock terminal is now a **dark teal glass display inside an ivory/antique-gold bezel**, with gold/chart highlights harmonized. All original charts, selectable 5 fictional tickers, execution/fee estimators, order ticket, stock trade controls, touch areas, deposits and game logic remain in place. The main ivory board isn't covered by a new permanent overlay.

## Validation

- Source audit verified the stock move branch is integrated into the ONE `IntegratedBankLedger` and game cash; SwiftPM UI imports Persistence.
- Three additional XCTest **source cases** cover signed receipt roundtrip in same game slot, legacy nil-key encoding/reading, forged receipt rejection. Xcode iOS15 compile and full package XCTest remain **NOT RUN**.
- The actual device kill/back-to-back trades/restart and disk-corruption tests must be completed before publishing.
- No changes to `main`, game rules, Protocol 4, release, IPA or GitHub workflow.
