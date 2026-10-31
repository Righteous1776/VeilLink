# Validation plan

1. **Geometry.** Test all eight `(±1,±2)/(±2,±1)` offsets; reject off-board indices; test translation, 90° rotation and reflection equivalence.
2. **Containment direction.** With two opponent moves, assert that a legal knight-linked black candidate on the forward frontier ranks above an equally linked candidate behind it. Reverse the opponent vector and assert the preference reverses.
3. **No fictional confinement.** Assert the policy never changes legal-move generation and never labels a board “sealed”.
4. **Safety gate.** Run forced five and forced opponent-four fixtures. The tactical win/block must win irrespective of containment score, developer lesson or training level.
5. **History isolation.** Replay a held-out owner export in a temporary store; verify no player history is cleared, no duplicate completed games are introduced, and profile export/import round-trips only its own metadata.
6. **Strength.** At each difficulty, run colour-swapped paired games against formation-off with identical openings. Report game count, win/draw/loss, exact sequence and symmetry coverage, SHA-256 of external raw JSONL, and Wilson interval. Do not promote unless the predeclared threshold passes.
7. **Device budget.** iPhone 7 regression: master difficulty keeps existing time cap and UI remains responsive; lower difficulties receive no hidden compute increase.
8. **Release gate.** Only after a Governor-selected integration passes XcodeGen, full XCTest, physical device validation and release authorization may an unsigned IPA be produced. This proposal must not start that workflow.
