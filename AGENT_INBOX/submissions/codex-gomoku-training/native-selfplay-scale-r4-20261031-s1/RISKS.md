# Risks — S1 native training and Bagua analysis

- S1 is an external research corpus only. It has **not** been imported into VeilLink, so neither App learning count nor production strength may be claimed.
- The Foundation compatibility shell reproduces the `GomokuState` and learning API slices needed to compile unmodified PR #114 Bot source; it is not an iOS build or a substitute product integration.
- `GomokuBot` uses wall-clock budgets. Fixed seed does not promise bit-identical search depth under different host load; every run records engine and runner hashes.
- A single preset first stone is allowed for coverage but is not a Bot decision; reporting keeps those counts separate.
- S1's 254 exact sequences in 1,000 games still signals substantial repetition. S2 must improve held-out family coverage before mere volume growth.
- Existing Bagua preference failed the 400-game non-degradation gate. No default activation, no claim of deep-learning improvement and no replacement of PVS/VCF is allowed.
- Deep formation analysis is evidence-driven and exportable, but no external model weights, player data, archives or binaries may enter Inbox.
- PR #112/#113/#114 remain stacked Drafts; #113 has a failing iOS CI status and #114's exact-head CI was in progress at takeover. Product integration remains Governor-only.

## Overlap

This evidence overlaps the native self-play/formation surfaces of #110–#114. It proposes no product patch and does not resolve those overlaps.
