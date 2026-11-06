# Kimi K2 2.5D board · ID / hash / source integration map
Task: `VL-K2-BOARD-INTAKE-20261107`. Current baseline at original selection `7244dc6cc57f6330e2cd9311843003d31f4bdfbd`; current branch `dev/veilopoly`.

## Decided selection
**15 program-generated PNG assets** are accepted as the preferred replacement candidate for **only the board rendering layer**. See `KIMI_K2_SELECTED_ASSET_LOCK.json` for each immutable `VL-K2-ART-001..015`, SHA-256, expected Git blob SHA-1, size, L0-L3 placement, source member, staging path and eventual runtime target.

**40 board cells** have immutable IDs `VL-K2-TILE-000..039`, corresponding original `tile_00..tile_39` aliases. See `KIMI_K2_TILE_MAP_40.json`: indexes, atlas pixel rects, UV, position and edge rotation.

## Missing source touchpoints (proposal only)
| Source / method | Existing gap | Selected Kimi binding |
|---|---|---|
| `BoardScene.swift` `init`, `buildBoard()` | flat base/frame/color and centered text | L0 boardTable, L1 boardEdge/boardBase/boardFrame, L3 boardCenterEmblem |
| `BoardScene.swift` `buildBoard()` 0...39 | `SKShapeNode` tile placeholders | tilesDark/Light + 40 tile UV rectangles |
| `BoardScene.swift` `point(_ i:)` + `tokenPoint` + board hit-test | old coordinates differ from Kimi K2 layout | migrate **entire** geometry coherently; do not only skin tiles |
| `BoardScene.swift` `display(_ state:)` | owner/mortgage/building simplified glyphs | ownerStripes, tileMortgageOverlay, buildingShadow with legacy house/hotel |
| `UI.swift` | Astra dark UI and independent collapsible drawer | retain UI, Kimi board visual only; light theme remains later gate |
| `Package.swift` SwiftPM resource processing | existing `.process("Resources")` already present | binary may enter Resources only after separate review; NO package changes |

## Compatibility & integration order
- **B01:** stage original PNGs; verify SHA and Git blob hashes; make dark board+40 tile SKSpriteNode renderer optional, legacy fallback retained.
- **B02:** owner overlay, mortgage, building shadow, center emblem; do not change `GameState`.
- **B03:** optional light theme and independent icon mask only after UI contrast and render memory validation.
- Tiles have 2048×1280 atlas pixel size, Kimi's top-origin pixel rectangles, SpriteKit bottom-origin normalized UV. Use `KimiK2AtlasGeometry.bottomUV`; four corner indices 0,10,20,30 need explicit rotation and hit-test verification.
- Base/frame layers are pre-baked with projection. Do not apply boardPlane yScale to already projected textures a second time.
- Names, prices, cash and ownership come from Engine, never Kimi preview text marked `CANDIDATE_NOT_APPROVED`.
- The model's on-disk `SPRITE_MAP.json` is the original 114 KB; compact 40-cell map is staged in GitHub for deterministic alignment. No opaque full 2.5D screenshot should replace clickable tiles.
- Owner's later UI requirement overrides old Kimi full-preview screenshots: maximize board, operation entry at lower right, upper-right More/Exit separate; action drawer stays Astra.

## Reality check
Completed: original ZIP 36/36 SHA256SUMS, selected PNG 15/15 SHA, CRC, decode, local 40 tile UV ranges; GitHub **text maps / source catalog / XCTest source**.
Pending: GitHub PNG binary upload (0/15 at lock time), actual SpriteKit runtime hookup, Xcode iOS SDK, touch/safe-area/60fps/gpu, visual owner sign-off.
The recorded `expected_git_blob_sha1` field is an **expected content-derived ID**, not proof GitHub already contains the blob.
