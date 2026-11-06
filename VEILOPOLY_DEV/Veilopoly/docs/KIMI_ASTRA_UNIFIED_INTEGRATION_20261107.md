# VEILOPOLY P4 · Kimi-first integrated 2.5D board checkpoint

Task: `VL-P4-KIMI-ASTRA-UNIFIED-20261107`. Baseline: `629f7534ac7645db55304304b28040d48ccb2750` on `dev/veilopoly`.

## Accepted integration
- Promoted the exact 15 Git-SHA-verified Kimi K2 board PNGs from INCOMING_ASSETS into VeilopolyUI SwiftPM Resources without changing bytes (Git trees reuse blob IDs).
- Built `KimiK2BoardSkin.swift` to load the complete dark theme set; failing any required texture falls back to original procedural board. Original Astra B01 button skin, five hero transaction cards and native controls remain canonical.
- Kimi 40-cell atlased sprites use bottom-origin UV from `KimiK2TileMap.swift`. Gameplay positions, token movement and tile tap targets now share identical Kimi visual centers when the skin is active. Left/right/top/bottom rotations derive from authoritative 40 tile specifications; no double-applied 15° board perspective.
- Dynamic tile names/prices are sourced exclusively from `GameState`. Owner stripes and mortgage textures are data-driven, improvements remain from Engine counts. No Kimi example map/transaction rules or stale static HUD overwrites gameplay.
- The newest Owner UX preference is preserved: maximized iPhone landscape board and separate bottom-right action entry vs top-right More/Exit capsule.

## Important limitations
- Kimi 15 PNGs in SwiftPM Resources are the **existing 15 original assets**, while Kimi K2/K3/K4 additional token and FX candidates are still not all integrated. Avoid blanket claims of complete visual adoption.
- `KimiK2BoardCatalog.runtimeEnabled = true` means attempt Kimi dark rendering. The install preflight returns nil on any missing texture; it does not prove SpriteKit/iOS compilation or on-device visual acceptance.
- Full Xcode SDK / iPhone hit-testing / frame-time / shader/performance tests are **NOT RUN** in this Linux integration session. Portable Swift 6.2.1 engine tests are independent of iOS compile.
- The project `main` is NOT touched. This branch may only be promoted through Governor integration once actual iOS build/XCTest and compatibility gates pass.

## Follow-up
1. Finish ingestion of Kimi normalized 4 player tokens and accepted effect sprites, avoiding duplicates with K1.
2. Run iOS 16+ Xcode build and tests, specifically 40 tile UV, correct label rotations, no iPhone hit-region drift, card overlay/RenderCommand ACK.
3. Review K2 owner-strip alignment, bottom-center Kimi artwork positioning, 2.5D layer z, memory on device.
4. If verified, curate a P4-to-main integration PR through the Governor, without direct main overwrite.
