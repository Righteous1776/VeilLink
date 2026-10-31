# Risks & overlap

- **External validity**: 62,500 simulator matches are real but use a simplified surrogate, not the shipping GomokuBot. Naive wins or Elo claims are forbidden.
- **Insufficient positive evidence**: higher knight weights show major regression; 50 has heldout 0.20 percentage point advantage on n=2,500, far below measurement noise. No style bonus should be auto-applied.
- **Tactical limitation**: the new gate blocks a single immediate loss; it cannot save positions with two independent winning threats, and may miss a forced multi-ply win that needs depth search.
- **Performance**: one extra O(candidateCount × four directions) scan; small but validate 100ms budget on legacy profiles.
- **Training data**: 28 games / 18 unfinished; highly correlated openings, not enough to fit a general strong neural network.
- **Licensing**: Rapfi GPL-3.0 must not be silently linked/distributed; borrowed external models may contain nonredistributable weights and incompatible rules.
- **Governance**: overlaps #110 Bagua formation and learning store but **does not mutate** those files; Governor arbitrates. No release, version, dataset seed, app resource, CoreML weights or workflows changed.
- **Test coverage**: two Swift fixtures not executed on Apple/Xcode in this submission; static patch alone does not certify iOS behavior.
