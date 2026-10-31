# Reproducibility and provenance

Synthetic rules: 15x15 freestyle, no renju forbidden moves, alternate black/white, stop at first 5+ line or 90 ply cap (unfinished timed games counted as draws). Each move chooses radius-2 neighboring empty squares, checks immediate own win, then immediate opponent win/block, then ranked static run score/centrality + optional knight bonus. Pseudo-random exploration parameter 75/1000; shared policy and paired color swaps. Training uses 10k for each style 0,50,200,800,3200; validation 2.5k each from different seeds. Results are deterministic for the saved tool source.

Input user file SHA256: `034057959faa8bf45b571fee19b63fda646a27344eeee997216e9921157d5243`, FNV payload `c52154f68a0cb20c`. Source already in Owner's earlier Inbox PR #110; **not duplicated** here.

Run source files (Owner-local training kit, not committed as model weights):
- `veillink_gomoku_selfplay_train.py` SHA256 `1d1463beaf4da1567963e1fbf2b5a3424d239c9dba2b4dbd2439b1d3e170ca38`
- `veillink_gomoku_validate.py` SHA256 `8b36e9b30f7c57df43b162b798465cb116d4206dec5729e02c0efb28e23f310f`
- JSON report SHA256 `34dc377670535d762fbb066ffb1bd49b069de07a80dc5f188672c27267db6ba5`
- ZIP kit SHA256 `3520171ecde2c4f4a831f73d5c179663906543cf278ac9182239506ebf3bf300`

Command: Python with NumPy+Numba; run the trainer and validation scripts in a sufficiently long-lived local process. Do not expect full run to fit a short browser/request timeout. Every deployed model candidate requires a separate production review.
