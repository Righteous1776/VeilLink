# Goal

Teach the native Gomoku Bot the owner-defined **Veil 八卦阵** as a dynamic containment style:

1. Black forms a connected, chess-knight-step lattice; a link is `(|Δrow|, |Δcolumn|) = (1,2)` or `(2,1)`.
2. Opponent stones do not have a legal movement range in Gomoku, so “困住” is implemented honestly as constraining their *effective tactical choices*: cover their forward threat frontier, retain black lattice connections, and keep a counter-threat.
3. When the opponent's last two legal placements define an escape vector, black extends the lattice toward that frontier rather than replaying one fixed diagram.
4. Immediate win and mandatory block always outrank formation preference. A style score may never claim an unbreakable formation or suppress a legal tactical defense.

## Why R2 is necessary

The existing R1 evidence correctly records the owner's knight-step tendency, but PR #114's `bagua` preference only asks whether the candidate is a knight move from the *last* AI stone. It has no opponent direction, no enclosure/frontier concept, and cannot generalize the screenshot across translation, rotation, reflection or a change of opponent direction.

## Proposed native policy

The target is the native Swift Bot, not a diagram classifier and not a neural-weight import.

- Keep the existing opt-in `GomokuFormationMode.bagua`.
- Pass both black/AI history and opponent history to `GomokuFormationPreference`.
- Compute `e = opponent[last] - opponent[previous]` when two opponent placements exist. A candidate earns a bounded containment component only when it both (a) is knight-linked to at least one recent black lattice node, and (b) lies in the forward half-plane of `e` from the opponent's latest stone or closes the nearest frontier gap.
- Reward a *connected* lattice (one or more knight links), not just a jump from the final black stone. Cap formation contribution at 180, below existing tactical priority; do not activate until at least three black moves and two opponent moves exist.
- If the opponent changes direction, recompute the frontier from the latest vector; do not keep extending an obsolete ray.
- Preserve the R1 discovery registry as evidence only. A discovered pattern requires completed-game outcomes and paired evaluation before it can alter automatic mode.
- Store/export the owner-originated profile as a small signed JSON metadata package. It contains geometry, thresholds, provenance string `owner-created`, and no model weights or player-history overwrite.

## Training and promotion

Use the existing owner corpus additively, then create controlled position suites by applying its recorded legal prefixes under all 8 board symmetries. Those are evaluation/augmentation cases, not fabricated player games. Train only from completed real games and retain the existing separate player archive.

Promotion requires all of the following:

- static symmetry, legality and immediate-win/block tests;
- held-out owner-game replay with no archive mutation;
- colour-swapped paired tournament against formation-off at each chosen difficulty;
- no regression in forced-win/forced-block corpus or iPhone 7 time budget;
- a documented positive confidence interval, not one attractive screenshot or self-play-only result.

The prior 400-game Bagua-vs-off result (49.75%, 95% Wilson interval 44.88–54.63%) is a **failed promotion** and remains non-default. R2 starts as opt-in and must earn a new result.
