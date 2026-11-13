# W11 proposal — Independent financial activity during other turns (NOT IMPLEMENTED)
Owner asks to buy/sell virtual stocks and manage accounts while AI or another human is taking a turn. Source audit confirms CURRENT CODE DOES NOT ALLOW THIS.

## Verified current behavior
- UI.swift `GameSessionModel.perform` returns when `pending`, `cardGate.isPresented` or guest is not `waitingForHuman`; constructs Move(player: actor, seq: game.nextSeq).
- `VeilopolyEngine.apply` enforces `move.player == expectedActor` for the current game phase and `ctx.allowedMoves`. This rejects out-of-turn economic commands.
- Host commitOnHost and guest proposal/commit snapshots depend on canonical sequence/hash. A side command cannot be performed without sequencing and authority checks.
- Periodic stockTick presently runs only in allowed human .manage phase, not as a true independent market clock. Portrait widgets mirror the actual last committed price rather than fabricate updates.

## Proposed safe protocol / product decision
A. Define a separate explicitly permitted side-action category: stockBuy/stockSell, bank deposit/withdraw/repay, etc., with explicit Owner rulings for borrowing, transfers, mortgage/construction and auction interaction.
B. Move identity must use authenticated LOCAL seat, not acting turn ID. Validate capability, seat ownership, liquidity and pending-debt restrictions under the authoritative reducer; preserve one total monotonically ordered nextSeq. Never let an off-turn action consume the active player's dice/auction decision.
C. On live multiplayer guest, send a signed/authenticated side-action proposal over existing control lane. Only host serializes/commits to canonical sequence; guests dedupe by packet identity, reconcile missing commit with snapshot and never spend speculatively.
D. While animation/card decision is showing, side-action intents queue in an explicit bounded host-owned order; commit at deterministic barriers and update both UIs. Revalidate balances on commit, display rejection, never auto-repeat an old order.
E. Consider market clock authority: only host generates deterministic seeded stockTick at defined clock/turn boundaries; no local guest time-driven price forks. Preserve old saves/rules via versioned new-match setting or policy gate, with replay and migration tests.
F. Run paired host/guest tests: concurrent actions during AI turn, auction, card reveal, low bank liquidity, background/foreground, packet loss, duplicate orders and crash resume. Device evidence required.

## Ownership boundary
Engine/Net and live host bridge changes are outside this UI-only Inbox lane. Owner + Integration Governor must delegate to `codex-veilopoly` or an approved integration lane. This document is a SPEC_DECISION request, not implemented behavior; do not deceptively enable buttons while they still fail validation.
