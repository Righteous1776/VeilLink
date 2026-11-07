# Generated tile materials and readable composition

Task `VEILOPOLY-TILE-ART-007`, baseline `56f3790fc3fcf107da6925f25843a42ce14d3f94`. Owner supplied a close-up of jail / electricity / street tiles and requested more generated local artwork.

## Actual changes

- Two OpenAI image generations: a transparent ten-symbol sheet (go, jail, park, go-to-jail, railway, electricity, water, chest, chance, tax) and one blank ivory/brass property tile. Original images, hashes and mechanical extraction are preserved in `INCOMING_ASSETS/ASTRA_TILE_ART_R1` and `tools/normalize_tile_art.sh`.
- Eleven runtime RGBA PNGs: ten 128px symbols, one 256×384 blank face, 270,553 compressed bytes total (~1 MiB decoded). No preview text or prices are baked into the replacement face.
- The generated set replaces atlas tile faces atomically only when every texture loads. Tile IDs, centers, dimensions, rotations, touch shapes and ownership/building/mortgage logic are retained. If one new asset is missing, the entire old atlas/mask path remains available. Original Kimi files are not overwritten.
- Icons are selected from actual `GameState` tile kind, not the old atlas's sample artwork. Property colors, owner strips, names and prices remain live data; the colored strip is a state cue, not procedural illustration.
- Name, price, special icon and building placement use screen-oriented local coordinates. Labels cancel the tile's edge rotation. Full street names wrap into at most two lines; special-tile labels use one smaller line. The old unconditional four-character truncation is removed for the new art path.
- Buildings use an independent reserved row near the screen-top of each tile; name and bottom-price zones do not overlap it. Owner markers occupy a separate thin bottom strip. Generated special symbols avoid being drawn beneath the name.
- Group bands occupy the inner tile edge while names remain upright; top-edge prices move above that band. Two independent shallow decorative card stacks mark chance/chest in the central free area using the same generated face and icon assets. They do not create extra card-draw actions or change deck state.
- The supplied classic-board reference was withdrawn by Owner. This implementation follows Veilopoly's existing emerald/ivory/brass material language; no full-board reference image is installed as a gameplay texture.

## Validation and limits

`AstraTileArtworkTests` covers all bundled dimensions/alpha formats, special-tile icon availability, two distinct utilities, coordinate conversion and separated name/price/building zones on all 40 rotated cells. Guarded Apple tests cover full live names, upright labels and all-or-nothing missing-art fallback.

`tools/preview_refined_tiles.sh` builds four source-layer samples using real textures and representative current Engine names/prices: jail, electricity, four-house street and wrapped bottom-edge street. Both the source artwork and composed layout samples were inspected. They are not iOS screenshots, and the houses are a demonstration state, not a saved game.

The full board remains small on an iPhone; selecting a tile opens the existing larger inspector. Artwork and layout fixes do not make 40-cell labels readable at arbitrary zoom. Apple SDK type-check, SpriteKit line layout, font fallback, real safe areas/touch and visual inspection at device scale remain pending.

Local Swift 6.2.1/Linux: `swift build --jobs 2` → success → PASS; `AstraTileArtworkTests` → 3/3 → PASS; full `swift test --jobs 2` → 159/159, 0 failures → PASS; runtime manifest SHA-256 → 11/11 → PASS. ARM64 iOS16 frontend parse, shell syntax and `git diff --check` → PASS. Guarded Apple tests were updated but remain unexecuted on Linux.
