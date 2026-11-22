# Review and rollback

- PR #52 proposes the original Message Forge, including its engine, view and test class. Its staged engine is byte-identical to this proposal's main baseline. Review integration order to avoid replacing these corrections with the older staged files. The FORGE industrial theme work is separate.
- A qualifying pause now starts a fresh tap measurement. Tap timestamps closer than or equal to 200 ms are ignored. The first tap of a fresh sequence keeps the displayed tempo until a second tap arrives.
- Bullet formatting uses punctuation heuristics. A period followed by whitespace can still be ambiguous in an abbreviation. Chinese sentence terminators and semicolons retain their existing behavior.
- Segments may consist only of whitespace when needed to preserve the original draft. The view displays a preview and performs no automatic multi-message send.
- No new dependencies, data migrations, changes to on-wire budgets, or device permissions. Revert the affected tool and its regression tests together if integration reveals a platform-specific problem. Each of the three tool changes can be applied independently.
