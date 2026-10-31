# VeilLink Gomoku Formation Lab — R1 (2026-10-31)

## Status / branch
- Branch: integration/gomoku-formation-lab-v1-20261031
- Stacked on Draft PR #112 external engine HEAD 6ec7cb76747cd3c7ab20d7493539e29ae9c2e495; target PR #112 branch, **NOT main**.
- Feature: **opt-in** "阵法学习" Menu on Local AI Gomoku page.
- Original native AI remains unchanged when mode = off; active formation mode uses native search and does not misrepresent the independent JSCore PVS/VCF engine as consuming preferences.
- No version/build/release/signing/IPA/schema/wire changes.

## Google Drive source provenance
User-owned folder: https://drive.google.com/drive/folders/1R9vVolZA149-lCOxJuVN9CEEEPBA--9r
1. VeilLink_Gomoku_Patterns_14244_20261031.zip, 35,544,458 bytes, 14,244 original generated PNG boards.
2. VeilLink_Gomoku_Training_NO_IMAGES.zip, 730,678 bytes, coordinates, 50 label classes, JSONL and NPZ.
3. VeilLink_Gomoku_Tensors_14244.npz, 182,734 bytes, X[N,15,15], y[N], split[N] and win_mask_freestyle[N,15,15].
All ZIP container integrity checks passed locally.
Full dataset includes 26 named three-move Renju opening SKETCHES and attack/defense/Bagua classes. It contains ZERO embedded human games and ZERO expert general-purpose next-move training labels. The diagrams are illustrative data, not proof that "Bagua" is unbeatable.
The source archive and model weights are NOT checked into the GitHub source tree.

## Actual offline pattern-learning experiments
- 11,684 train / 1,296 validation / 1,264 test diagrams.
- ExtraTrees, 160 trees: 32.04% test accuracy, 0.168 macro F1; not promoted.
- CNN, two-plane 15x15 input, convolution 32→64→96 and 50-class head: validation 87.96% accuracy, test 84.73% accuracy and 0.854 macro F1, Bagua binary F1 0.816. Saved as reproducible research checkpoint, **not bundled in iOS**.
- **Leakage warning:** 110 identical-board SHA-1 hashes appear across distinct splits, despite group_id split logic. Synthetic distribution, unverified win mask completeness, non-legal board construction and lack of real-game transfer mean these classification statistics are not reliable Elo/strength estimates.
- Training scripts, model weights and metrics are user-delivered separately for research; no Core ML import or device inference asserted.

## Product implementation in this branch
- GomokuFormationMode: off(default), automatic, Bagua knight-link, attack, defense, discovery.
- Formation preference is capped to +320 at the *root priority* of native GomokuBot. Existing immediate-win shortcut runs first. An adversary immediate-five window disables all formation bonuses. Search still evaluates opponent replies and rule-gates final actions.
- Novelty: completed-game movement-type signatures from the Bot's actual last four moves are stored in a dedicated capped local evidence registry. Candidates require at least five completed games, three Bot victories and victories > twice defeats before being considered as exploratory preferences. This does NOT certify a strategy; no new autonomous chess rule is invented or enforced.
- Candidate evidence is isolated to Gomoku UserDefaults, separate from Xiangqi, local adaptive board database and developer formation lessons; clear learning clears this evidence.
- If preference is enabled, the native engine consumes it; experimental JSCore engine remains available when preference is off. No source code copying from unlicensed diagrams.

## Acceptance gates before possible main merge
1. Full Apple XcodeGen, iOS simulator build, XCTest and XCUITest on exact feature-branch HEAD.
2. Confirm PR #112 exact-head CI, and decide whether to stack/rebase without overwriting the other Governor lane.
3. 15x15 freestyle forced win/forced block/overline test; start/restart/cancel; device latency and memory.
4. More-than-5000 paired native AI games across seeds, mirror side swaps, 95% Wilson bounds; prove it does not reduce quality.
5. iPhone 7 (if still supported) and iOS26 touch menu, VoiceOver, appearance, persistence and battery tests.
6. Explicitly verify no implicit release workflows will trigger on merged main; do not publish on a feature-only turn.
7. Independent source review and risk arbitration with Draft PRs #110 Owner Bagua and #111 forced block before any main promotion.

## Pending
The learned CNN is not an embedded move policy; the first feature is a conservative tactical-search preference and candidate extractor. Real strong-engine distillation requires licensed move targets, actual match results and a dedicated deployment gate.
