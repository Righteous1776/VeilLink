# V0.5.2 Local Code Rendering

V0.5.2 makes the 三国兵棋 battlefield an install-local, programmatic render surface.

- The 7x9 hex-board normalized layout is embedded as Swift static data and warmed during app bootstrap.
- Terrain marks are drawn from cached normalized line blueprints; no terrain bitmap or SF Symbol is used inside the battlefield.
- Cao/Yuan faction flags are generated with SwiftUI `Shape` + `Text`.
- Unit counters are generated with SwiftUI geometry, faction palette, glyphs, and strength pips.
- `TacticalGameViews.swift` and `TacticalLocalRenderCache.swift` contain no `Image(...)`, `UIImage`, or `AsyncImage` path.
- No network request or runtime image decoding is required to display the board, pieces, flags, or terrain.
- Local CI contains a regression guard that rejects image-loading APIs from the tactical battlefield and requires launch-time render-cache warm-up.

This is a rendering/performance checkpoint only. Protocol 4, VLGM1 v1, SQLite Schema V8, BLE game-link hardening, and tactical game rules remain unchanged.
