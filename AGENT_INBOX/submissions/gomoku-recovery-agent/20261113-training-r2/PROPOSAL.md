# Gomoku R2: real offline training and loop-break integration proposal

## Evidence
V29.0 two owner-exported packages verified against the original iOS FNV1a64 canonical JSON representation. Their 185 recorded events (71 human wins / 39 AI wins / 75 unfinished) contain 156 unique full action sequences, and 29 repetitions. Historical import is destructive replacement; never import two files sequentially expecting merged evidence.

From deduplicated histories, an exact five-in-row and fork teacher labeled 15,724 candidate decisions on 212 positions where a preventable opponent fork exists (533 safe / 15,191 unsafe). Train a 13-feature linear logistic surrogate using game-replay geometry, centrality, neighbor and open-window features. It is not an Elo or proof model.

Leakage-aware five-fold CV with six-ply openings connected by exact-board transpositions: learned surrogate selected a safe move on **202/212** held-out positions; historically selected AI moves were safe **153/212**. Exact deterministic tactical gate was safe on **212/212** by dataset construction. Never replace that gate with model inference.

Model package, full evaluation, sources, 185-record *experimental* merged .vltrain and SHA256 are delivered locally to the owner; no model weights or private game history pushed to repository. Model is offline only, not linked to the iOS executable. Offline teacher distillation results do not establish general win rate or actual iOS performance.

## Product proposal
1. Enforce own immediate win, unique immediate opponent block, R8 forcing win and R4 fork safety on *external* PVS/VCF suggestions. If unsafe, fall back to native.
2. When recorded human-game sequence evidence exists, do not route the move through PVS/VCF which currently ignores AdaptiveBoardLearningSnapshot; use the native learning-aware bot.
3. Add regression test for 5-times repeated a83 in h112/a96/... opening, forcing unique block and invalid move.
4. In a separate integration window evaluate JSON model as *secondary ranking only* after the exact hard gate; do not blend it directly into heuristic weights without XCTest and feature-extraction parity tests.

## Boundaries
This is only an advisory Inbox patch, no product-tree mutation. Do not run release signing/IPA/workflows or change version, A10, database schema, identity or transport. Existing R1 submission overlaps; reviewer must choose R2 as superset or carefully compare before integration.
