# Risks and overlap

- **Navigation behavior:** LazyVStack can defer construction/lifecycle of off-screen sections; verify destination state survives scrolling and return navigation.
- **Aesthetic tradeoff:** Hero shimmer and card 3D touch response removed ONLY from Game Lobby to prioritize reliable scrolling. Other screens keep their current interaction behavior.
- **Intermittent freezes:** Code-level evidence is limited to UI gesture contention and perpetual hero animation. Root causes outside Game Lobby may remain; require Instruments/MetricKit before targeted backend changes.
- **Overlap:** PR #100 (Monogatari lobby entry) references GameLobby; compare its current patch before applying. Prior integrated PR #139 addresses chat anchor/gesture and must not be overwritten.
- **Protected surfaces:** None touched by this patch. Do not alter database migration, BLE protocol, identity, A9/A10 authority, build numbers, GitHub Actions, or release outputs.
- **Status:** Proposed patch only; not compiled, tested, merged or shipped.
