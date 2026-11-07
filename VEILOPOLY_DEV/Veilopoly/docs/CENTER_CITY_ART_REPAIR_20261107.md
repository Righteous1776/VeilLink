# Central city art repair

Task `VEILOPOLY-ART-INLAY-005`, baseline `0978834e5120973440c9313a3c94c5b354753aa7`, branch `dev/veilopoly`.

## Observed defects and limits

Direct source image inspection and layer composition showed a very sparse center felt with a flat two-color emblem, simplified flat token art and tiny inherited house/hotel icons. These differ in material detail from the refined Astra controls and brass board frame. The scene is SpriteKit 2D/2.5D, not an actual 3D mesh scene: generated textures improve appearance but do not add movable cameras, geometry, physically interacting lights or true depth.

Some original tile textures contain preview labels; the existing live-label masks remain necessary. The two-color emblem and transparent frame can look like opaque gold squares in viewers that ignore alpha. Alpha-aware composition confirmed that these are transparent, so no incorrect matte-removal operation was applied to the originals.

## Applied local repair

Generated one original transparent financial-city diorama with the OpenAI image tool, then resized and padded for runtime. The city combines limestone, dark teal glass and restrained brass on a low oval plinth; its baked contact shadow joins the board without a rectangular image background. The same neutral-material inset works on dark emerald and light ivory felt.

`astraCenterCity.png` is 512×512 RGBA, 222,089 bytes, estimated 1 MiB decoded. Its full square bounds at 448×448 design points are (288,246)–(736,694); even these transparent outer bounds do not intersect any of the 40 rotated tile bounds. SpriteKit places it at (512,470), anchor (0.5,0.5), z=3.5. Tiles stay at z=4, existing labels, pawns and action feedback remain above it. No new touch handler, rule or label is baked into the image.

The new art replaces only the center-emblem sprite when available. If absent or undecodable, the original Kimi emblem is still loaded; required Kimi-board preflight and procedural-board fallback are unchanged. Theme switching retains the same center node. The original generation and SHA-256/bytes/provenance are retained under `INCOMING_ASSETS/ASTRA_CENTER_CITY_R1/`.

## Verification

`tools/preview_center_city.sh <output-directory>` uses original 40-cell metadata and source PNGs to compose day/night diagnostic art-layer previews. Both previews were inspected; there is no opaque rectangle, visible edge matte or tile overlap. These are source-layer composites, not rendered app screenshots; live GameState labels, dynamic masks, player nodes and UI are not rendered by this script.

ImageMagick confirmed alpha=0 throughout the outer top/bottom 24px margins. The runtime PNG hash matches `ASSET_MANIFEST.json`. Portable tests cover actual bundled RGBA dimensions/byte length and nonintersection against all 40 rotated tile bounds. An iOS-only test covers installed layer/position, retained identity during theme changes and missing-city fallback.

Local Linux Swift 6.2.1 full suite on the original task baseline plus this patch: 141/141 PASS. Art/resource selection: 5/5 PASS. ARM64 iOS16 frontend parse PASS for grammar only; shell preview syntax and `git diff --check` PASS.

After replaying the art change on remote `69acec5` (new save/resume code), the complete Linux suite passed again: 154/154, 0 failures. No existing remote save implementation was overwritten.

Apple SDK compilation, actual device scale, visual balance during movement/dice/cash animations and GPU memory measurement remain pending. Flat token/building material mismatch is documented for a separate targeted art pass; this repair does not claim to replace those assets or provide genuine 3D models.
