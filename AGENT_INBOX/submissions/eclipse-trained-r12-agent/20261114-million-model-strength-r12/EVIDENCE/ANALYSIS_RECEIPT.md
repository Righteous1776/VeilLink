# Retrospective independent analysis of frozen Codex PR #209

Base: `d93e579a1b01e66be77b8e2d45cf2c60cd58b1df`. Fitted Swift model SHA256 `f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe`.

Source files read: all 10 `EVIDENCE/RAW_ARENA/*.jsonl` (500 trained-vs-original complete games and 420 trained-vs-trained adjacent-tier complete games), generating 920 real arena records and 28,737 post-6-ply-preset decisions. Each placement was checked for occupied collision; 0 such errors.

For specific SHORT opponent-fork exposure diagnostic: after each actual move, exclude positions in which mover has already made a five (a previous first pass mistakenly counted one terminal win). Check the distinct opponent next-turn five-completion fork, and look for a radius-two nearby alternative which avoids both next-turn immediate opponent five and fork. Findings **on the 500 trained-vs-original subset only**:
- frozen trained branch: 6,844 decisions; 0 avoidable exposures.
- frozen original branch: 6,810 decisions; 54 avoidable exposures.
- These are potential short tactical errors, NOT an exact number of lost games. They are correlated within paired games and reuse the original Codex evaluation data. Do not advertise as novel held-out game win rate or strength multiplier.

Five public Codex baseline counterexamples were replayed in the prior R11 exact oracle under D4 transforms (5 source positions × 8 = 40 states, 120 checks PASS). R11's existing root safety correctly rejects their bad move when a safe alternative is in the supplied approved root set. Codex itself already contains an exhaustive root fork gate; R12 instead targets repeated fitted-model inference and search-horizon tactical safety.

Potential test leakage is contained: **nothing in the frozen fit or coefficients was adjusted using these 920 evaluation games**, and these fixtures are only retrospective engineering regressions. Fresh unseen openings required to establish improvement.
