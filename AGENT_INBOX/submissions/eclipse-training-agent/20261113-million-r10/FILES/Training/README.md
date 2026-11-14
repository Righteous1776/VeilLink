# ECLIPSE R10 training and audit

The frozen model fits **1,848,616 genuinely distinct D4 board/action orbits** from legally replayed real games. Validation has 120,343 alternatives; heldout test has 220,532. These are counterfactual legal alternatives, **not** millions of games, player moves or engine-search results. All training rows have positive weight in the actual fit. No repeated epochs, duplicate games, rotations or symmetric action cells are counted toward the figure.

Two owner exports supplied 105 terminal entries, or 92 distinct complete role/action histories. Their original native payload FNV checksums match, and seven known incomplete restored fragments are excluded by source SHA and 1-based sequence. Another 73 nonterminal entries are excluded from outcome supervision. The bundled native seed supplied 2,000 verified terminal games with many duplicate trajectories. Combined sources contain 317 distinct D4 full-trace families. Full traces are assigned to train/validation/test before extraction; shared side-relative D4 board identities are removed from evaluation. This does **not** establish full opening-connected-component independence: different games may share early opening structures.

The C++ teacher independently evaluates legal alternatives using remaining enemy fork cells, own new three-stone-window fork multiplicity, immediate completion count and local potential. It is a geometric tactical heuristic, **not minimax**, master labels or a winning proof. Exact multi-cell threat values are teacher labels rather than model inputs. A 26-feature histogram gradient boosting model is fitted on every retained training alternative. Validation chooses between predeclared 24/48-tree candidates; test is not used for selection. Final model has 48 depth-at-most-4 trees and 1,348 nodes.

`EclipseTrainedOrdering.swift` contains the actual fitted coefficients and trees as readable source, plus exactly matching local feature extraction. API:

```swift
EclipseTrainedOrdering.score(cells: cells, index: candidate, side: toMove)
```

The output is `clamp(rawPrediction * 12, -20000...20000)`, with the same side-relative model for black and white. It changes ECLIPSE search candidate ordering. Immediate win/block/fork proofs remain rule checks. The integrating search must compute each candidate score once before sorting; repeated feature extraction in the sort comparator is unnecessarily expensive. Root preference interaction and the chosen multiplier require native arena validation rather than a proxy claim.

Final nonforced test-board proxy, excluding immediate own wins, immediate opponent wins and existing own double-completion tactics: safe first choice 736/943 → 839/943; mean remaining enemy fork cells 0.40615 → 0.19300; teacher regret 48.2667 → 5.98738. These are candidate-ranking measurements, **not match win rates or Elo**. End-to-end arena evidence is separate.

`PARITY_AUDIT.json` independently verifies actual fitted arrays contain exactly one full D4 board/action representative, zero cross-split D4 board identity overlap, and 9,024 compiled Swift cases with zero feature/integer-score/floating-prediction mismatches. The latter includes both the original pilot's 2,000 fixed real heldout inputs and 2,000 fresh final inputs, color inversion and 1,024 D4/color cases. A separate brute-force scan checks 48 stratified tactical label cases with zero mismatches, including positive threat cases. No private boards appear in committed reports.

Run with existing NumPy, scikit-learn, g++ and Python; no dependency installation or GPU is required:

```bash
python train_ordering.py \
  --owner /path/to/1-VeilLink-GomokuLearning-20261113-172016-404-27774F62.vltrain.json \
  --owner /path/to/2-VeilLink-GomokuLearning-20261113-181938-942-EB7990D0.vltrain.json \
  --seed /path/to/VeilLink/Resources/GomokuNativeTrainingSeed.json \
  --work /external/private/training-work \
  --report-dir /path/to/this/Training
```

Compile `EclipseTrainedOrdering.swift` with `VerifyOrderingParity.swift`, then run `audit_training.py --work /external/private/training-work --swift-executable /path/to/verify_ordering --report /path/to/PARITY_AUDIT.json`. If the prior pilot fixtures are absent, parity checks 5,024 cases; the checked final session retained them privately and checked 9,024.

Raw boards, candidate arrays, private parity fixtures, executable and fitted joblib remain in the external work directory. They must not be committed to the Inbox. Text-only code and aggregate reports are sufficient to reproduce the run from the three input archives. `TRAINING_METRICS.json` records source, script, dataset and final source-model SHA-256 values. The final source-model SHA is `f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe`.

The frozen model has **not** consumed the current arena or difficulty calibration results. Using those results for a later fit would require a fresh heldout arena and a new model identity. Running training does not import data into the app, replace player history, promote defaults, merge source or release an IPA.

## Exact execution environment and commands

Executed on x86_64 Linux with Python 3.12.14, NumPy 2.3.5, scikit-learn 1.8.0, SciPy 1.17.0, joblib 1.5.3, g++ 14.2.0 (Debian 14.2.0-19), and Swift 6.2.1 (`swift-6.2.1-RELEASE`). Training limits were `OMP_NUM_THREADS=3` and `OPENBLAS_NUM_THREADS=3`; fixed random seed 20261113. Dependencies were already installed. Final fit and export took 31.36 seconds in this session; this is a host measurement, not iPhone performance.

From `/workspace/VeilLink`, the exact final training invocation was:

```bash
python AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training/train_ordering.py \
  --owner /tmp/codex-remote-attachments/6af7402f-0e74-8191-995b-c53753ad0020/C3A5CFFE-7ABC-42D8-BDBE-E78FC2B46CE8/1-VeilLink-GomokuLearning-20261113-172016-404-27774F62.vltrain.json \
  --owner /tmp/codex-remote-attachments/6af7402f-0e74-8191-995b-c53753ad0020/C3A5CFFE-7ABC-42D8-BDBE-E78FC2B46CE8/2-VeilLink-GomokuLearning-20261113-181938-942-EB7990D0.vltrain.json \
  --seed VeilLink/Resources/GomokuNativeTrainingSeed.json \
  --work /workspace/scratch/eclipse-training \
  --report-dir AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training
```

Exact final Swift audit invocation:

```bash
/workspace/scratch/swift/usr/bin/swiftc -O \
  AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training/EclipseTrainedOrdering.swift \
  AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training/VerifyOrderingParity.swift \
  -o /workspace/scratch/eclipse-training/verify_ordering_final
python AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training/audit_training.py \
  --work /workspace/scratch/eclipse-training \
  --swift-executable /workspace/scratch/eclipse-training/verify_ordering_final \
  --report AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/Training/PARITY_AUDIT.json
```

Raw source SHA-256 values:

| Source | SHA-256 |
| --- | --- |
| Owner export 1 | `d5cf13940bbb84dc937783700aa129303c4ec1d54a781992099675c3e6325d8b` |
| Owner export 2 | `050f5abbac2c3f7991db5dbcad4b4d1bd33f49eb1aeeacb5025b17d0696ce325` |
| Bundled native seed | `9f7ddf5c847d6beb972c5a98ad83daa66df189f82171988ac1da68d6142188e0` |

Persistent session artifacts in `/workspace/scratch/eclipse-training` are `boards.txt`, `board_splits.npy`, `board_sources.npy`, `candidates.f32` (2,195,214 alternatives before action-orbit filtering), `candidates_d4_unique.f32` (2,189,491 retained alternatives across the three splits), `fitted_model.joblib`, `parity.jsonl`, `training_report.json`, and logs. Private pilot artifacts remain in `pilot_model/`; they are not the final fitted model. A host workspace is not a permanent external archival service. Only the text source and aggregate reports belong in the Inbox.

The initial pilot fit contained 5,204 symmetry-equivalent training action rows. Those were removed **before the final refit**; 519 corresponding test redundancies were also removed. The final validation protocol was unchanged. Previously observed pilot test/arena scores were not used to tune the corrected model. The final metrics report and model hash supersede pilot results.
