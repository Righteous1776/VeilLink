# Veilopoly Kimi K2 visual geometry and importer gate (2026-11-07)

Task VL-K2-BOARD-INTAKE-20261107, continuation from dev/veilopoly @ 6ab6d030bf67e3c31a97f6843ce30eb10b042709.

- Adds KimiK2TileMap.swift with exactly 40 immutable visual coordinates, atlas pixel rectangles, 2.5D cell rotations and bottom-origin SpriteKit UV calculation. Does not touch game-state or old renderer.
- Adds one regression test to KimiK2BoardCatalogTests for ID/index uniqueness, coordinate bounds, UV bounds and four corner rotations.
- Hardens importer to read-only by default; opt-in --stage. Validates 36 source SHA records, source ZIP SHA, 15 PNG SHA256 and expected Git blob SHA1, and 40 compact-to-original tile map records.
- Refuses branch mismatch, out-of-scope stage path and inconsistent existing output before any write.
- Standalone Swift 6.2.1 compiler + smoke validation completed locally: 40/40 geometry records, UV ranges, four-corner rotations PASS.
- This is not an exact remote-head Xcode/iOS UI build. The 15 asset PNG binaries are still NOT uploaded to GitHub. The local 500KB selected handoff ZIP contains the original art.
- Retains Kimi preferred board, Astra interaction HUD, the owner's separate top-right Exit and bottom-right operation entry, and unchanged production main.

Next milestone: authenticated staging of 15 PNGs, independently verify actual remote Git blob SHA1, then guarded BoardScene sprite/atlas rendering and iOS touch/safe-area tests.
