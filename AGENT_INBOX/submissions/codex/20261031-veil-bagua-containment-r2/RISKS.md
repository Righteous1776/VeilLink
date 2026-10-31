# Risks and overlap

- **Semantic risk:** Gomoku has unrestricted legal placements; "困在点阵内" must remain a strategic objective, never a false legality restriction.
- **Evidence risk:** the supplied image is a final board, not a move sequence. R2 uses PR #110's documented export statistics and user-stated rule; it does not fabricate chronology.
- **Strength risk:** R1's paired control failed promotion. R2 is opt-in until a fresh independent tournament clears the threshold.
- **Overfitting risk:** a fixed starting point or one diagram would make the bot predictable. Require symmetry/translation tests and direction-change cases.
- **Compatibility risk:** #110 supplies owner seed evidence; #113 adds formation modes; #114 adds native self-play/import. All are Draft and overlap `GomokuFormationLearning.swift`, `GomokuBot.swift`, `LocalAIGameController.swift` and tests. Governor must arbitrate stack order; this lane does not resolve them.
- **Performance risk:** larger lattice scoring must remain bounded and must not bypass iPhone 7 budgets.
- **Ownership risk:** the name and rule are owner-originated. Keep provenance as `owner-created`; do not import web claims or third-party model weights.
- **Release risk:** no live-lane grant permits changing version, signing, IPA packaging, main, or release publication.
