# Proposal — preserve S1 native evidence; do not promote Bagua yet

## S1 facts

The new corpus is real self-play using the target product's PR #114 Swift `GomokuBot.chooseMove` implementation. It is not a diagram classifier, a Python move generator, a synthetic tensor, or an App import.

- New complete games: **1,000**
- New actual Bot decisions: **51,292**
- Preset opening stones: **1,000** (one per game, excluded from Bot-decision count)
- Invalid / unfinished games: **0 / 0**
- Results: host/black **533**, guest/white **462**, draws **5**
- Exact unique full sequences: **254**; symmetry-normalised sequences: **186**
- Exact pre-move positions: **12,532**; symmetry-normalised: **7,373**
- Coverage: all **225** board openings and all **36** ordered black/white formation-mode pairs.

The pre-existing 2,000-game bundle was separately replayed, not counted as S1: 2,000 complete games, 91,530 Bot decisions, 236 exact sequences, 10,710 exact pre-move positions, 0 invalid.

## Bagua evidence and decision

The new Bagua export records same-colour movement signatures (`N` knight-style / `D` diagonal / `L` line / `X` other), per-side outcomes, terminal signatures and loss cases. It is an explainable formation analysis, not a claim that a neural network has learned a guaranteed strategy.

In the mixed S1 corpus, Bagua appeared asymmetric: black 93W/74L/1D over 168 games, white 64W/102L over 166 games. A stricter independent colour-swapped control used 200 identical opening blocks (400 games): candidate Bagua scored **199.0 / 400 = 49.75%**, Wilson 95% CI **[44.88%, 54.63%]** against native formation-off. The lower bound does not exceed 50%; therefore the current Bagua preference is **not promotable as a default**.

## Next controlled work

1. Keep Bagua opt-in and preserve immediate-win / immediate-block priority.
2. Mine the exported Bagua loss records to build labelled counterplay lessons; do not silently rewrite a player archive.
3. Run S2 with held-out opening families, then a 1,000 paired-block Bagua/anti-Bagua test before proposing any tactical adjustment.
4. Design only an additive, checksummed export/import package for accepted lessons; do not lift the v1 10,000-record / 3 MiB guard by force.
