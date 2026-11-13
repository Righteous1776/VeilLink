# V9 tactical strength project — governed integration candidate

## Verified upstream baseline

Current main eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0 already includes GomokuBot R4 counterfork filtering, R6 learned defense, R8 forced double-win detector, native self-play, formation learning, and opt-in JS PVS/VCF. Earlier 2026-10-31 Inbox work includes 62,500-surrogate-game tactical screening and 2,000 executed native self-play matches. The latter's Bagua candidate was quarantined (49.75%/400), so no blind import into production.

## Proposed implementation

1. Preserve original four difficulties for all saved games and comparison tests. Add Gomoku-only 棋圣(2x), 传奇(4x), 天元(6x); seven Gomoku choices, four Xiangqi choices.
2. Scale search wall-clock budgets from the Master preset: 950ms full -> 1900/3800/5700ms; 420ms opt-in economy -> 840/1680/2520ms. These are compute-budget multiples, not established strength/Elo multipliers. Preserve training reinforcement without accidentally clipping higher-level budgets to 1100ms.
3. Add V9 proof-only forcing-four chain search, allowing 2/3/4 attacker plies on extended tiers. Exactly one immediate-five completion forces a defender's block unless they can win now. Two distinct completions prove next-turn victory if defender has no direct win. Search is node/time bounded and never treats an incomplete search as proved.
4. Keep the existing mandatory own-win, opponent immediate-win defense, R8 double-win proof, R4 fork safety and R6 ordering ahead of ordinary ranking. New proof is after R8 and before heuristic ranking. Existing four modes stay byte-for-byte path compatible via forcingDepth=0 default.
5. Ensure opt-in JS PVS/VCF adapter does not cap newly requested time budgets at 1400ms. JS engine already hard-clamps maxDepth to 8; extended tiers request 7/8/8 within that cap. Keep native learning/prediction path distinct from JS claims.
6. No device-specific forced downgrades. Human can explicitly choose economy. Offline only; no storage change, network, model weights or ML inference requirement.

## Gates before claiming 6x chess strength

Measure tactical suite solve rates, illegal move count=0, missed mandatory defense=0, scored paired head-to-head against frozen V29 baseline, opposite seat per opening, same hardware and equal compute budget (plus separate unconstrained product mode), 95% confidence interval, ≥5,000 completed valid games, no counting move-capped games as draws. Use a rating estimate and identify exact metric for 6x; do not call compute multiplier Elo multiplier. iPhone13 and iPad long-session thermal/memory and both iOS mode tests required. Keep behind Governor review until validated.
