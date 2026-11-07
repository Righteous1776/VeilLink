# GPT CONTINUATION-003 — W2 invalid reference hardening

Baseline `dev/veilopoly@2a0975e`; main remains `2c5b516`. Pure Engine guard rejects malformed auction participants, trade parties/tiles, debt creditor, current player, negative deck cursor, and overflow counters **before** any phase-dependent indexing. Prior dedicated purchase/auction invalid-tile errors remain in their move handlers; no rule/seed/RNG/schema changes.

New `MalformedTurnReferenceTests`: 4 source tests with failure-atomicity and healthy deterministic replay. Full SwiftPM tests / Apple SDK / simulator / device **NOT_RUN** in this tool environment; do not claim them PASS. No main, host transport, protocol, version, packaging or release writes.

Next: independently run full SwiftPM regression and Apple type-check, then optimize large-snapshot resilience and test weak links.