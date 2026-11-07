# Board Training R4 · Opponent Counterfork & Low-End Runtime

> Integration Governor / VL-BOARD-TRAIN-R4 / 2026-11-07

## Grounding / boundaries

- Parent: **R3 integration draft #170** (not `main`). This branch has no release or IPA authority.
- Scope: ~80% Gomoku tactical training, ~20% Xiangqi low-end implementation.
- **Gomoku genuinely trained:** replays of the owner's original v28 Gomoku exports, not invented new game wins. From nonforced real-position records, exactly **2,484** unique original boards permit the opponent to make a future double-immediate-win threat. Perboard exact rule-label enumeration of **49,716** candidate moves. Deterministic SHA-based **1,980 train / 504 heldout distinct board** partition.
- Target: the number of *opponent legal future fork squares* remaining after this candidate move. The offline teacher uses the exact five-in-a-row geometry. A 14-feature Ridge regression is distilled algebraically into seven features already computed by native R3 (`GomokuBot.trainedR4TacticalBonuses`). The original offensive R3 score is unchanged. Only adds a **[-48,000,+48,000] bounded defensive root ordering hint** after immediate win and mandatory block gates.
- This is **not** a neural net, solved game, Elo improvement, or expert game label. It is supervised tactical distillation into ~7 floating-point weights. No extra runtime model file.
- Original static-policy heldout counterfork elimination: **406/504**. Trained R4 signed-cap 48k on the same candidate set: **435/504**; heldout mean remaining enemy fork squares **0.34524 → 0.23413**. Training set was used to estimate weights and strength multiplier; this benchmark is a proxy score at the move-order stage, not the full `GomokuBot` result. Exact unrestricted policy got 437/504 but uses much more dominant 240k ordering score, thus rejected pending stronger engine-level AB validation.
- **Xiangqi actual runtime optimization:** preserves every learned R3 weight and move-order feature, but eliminates per-node allocations of 21-element `features` and `trained` arrays. Checked **12,692/12,692** identical integer scores over original lawful candidate-action dataset from **371** real observed board states. Local Linux Swift 6.2.1 `-O` 600,000-call synthetic microbenchmark measured ~**8.90×** speedup for the scoring function *only*. Not iPhone 7 app-level performance and no claim of chess strength gain.
- Historical user records, app learning DB, all personal chess archives and model training arrays remain off public GitHub; reproducible scripts & reports delivered separately to owner.

## Actual source integration

1. `GomokuBot.chooseMove`: one shared extraction of R3 attack and R4 defensive features, summed to candidate ordering, then existing native search decides final move. No hard-rule override.
2. `XiangqiBot.trainedR3OrderingBonus`: scalar evaluation, same coefficients; no data schema change.
3. `GomokuBotTests`: R4 defense positive on a double threat, zero on occupied cells, bounded; `XiangqiBotTests`: fixed four R3 opening score parity fixtures.

## Safety / release gates

- Native full-match R3-vs-R4 side-swapped same-openings A/B ≥200, iPhone7 legacy latency+memory+foreground test, all forced win/block checks, Swift compile and XCTest. **None of these pass by virtue of this document.**
- Keep #169 and #166 separate, do not silently cherry-pick conflicting code.
- If original native search A/B shows degradation or memory/latency regression, reject/Rollback R4 defense term rather than increasing coefficients blindly.
- CI is a passive PR trigger; do not dispatch more workflows or release.
