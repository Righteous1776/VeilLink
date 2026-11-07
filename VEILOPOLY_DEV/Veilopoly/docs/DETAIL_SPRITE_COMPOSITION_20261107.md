# Fine detail sprite composition

Task `VEILOPOLY-DETAIL-ART-006`, baseline `d06afc81351725c198b2625ba76b63306e80d982`. Owner requested generated local images rather than procedural drawing for artwork.

Generated one cohesive six-object sheet with the OpenAI image tool: blue pawn, red car, green ship, gold airplane, green-roof house and red-roof hotel. Painted enamel, stone and brass relate to the existing central-city miniature. The source sheet is retained with provenance, crop rectangles and hashes under `INCOMING_ASSETS/ASTRA_DETAIL_SPRITES_R1`.

Six extracted RGBA sprites are 128×128 each, total 119,511 compressed bytes / 384 KiB decoded estimate. Cropping, alpha trim, aspect-preserving reduction and transparent padding are mechanical processing of generated artwork, not procedural replacement artwork. `tools/normalize_detail_sprites.sh` reproduces extraction. Each has at least 8px padding on the narrowest canvas margin.

Board and player HUD share the same ordered token candidates: generated, original Kimi, original Kenney. Four player colors and silhouettes are retained. Formation, token dimensions, movement paths, shadows and exactly-once animation ACK remain unchanged.

The Kimi board loads generated house/hotel textures only as a complete pair; otherwise it retains both old building textures. Building counts follow authoritative house/hotel state and nodes still rebuild only on actual count transitions. Generated building sprites counter-rotate their parent tile so their baked overhead camera and upper-left light remain consistent around all four board edges. Positions and footprints stay unchanged; no sprite replaces dynamic price/name/owner text.

Alpha-aware diagnostic composition was inspected on a light background, and a separate 34px token / 14px house / 21px hotel sample was inspected against emerald felt. Details naturally disappear at tiny scale; roof color and silhouette take priority. These diagnostics are image composites, not Apple runtime screenshots. Original Kimi/Kenney art remains available for rollback/fallback.

Portable tests validate all six bundled PNG headers, dimensions, RGBA mode, byte counts and player fallback identity. A guarded Apple test checks actual token texture resolution and world-space building rotation. Apple SDK type-check, device compositing, perceived contrast/overlap and GPU measurement remain pending.

Local Linux Swift 6.2.1 verification: full `swift test --jobs 2` → 156/156, 0 failures → PASS; art/resource/formation selection → 8/8 → PASS; runtime SHA-256 comparison against the manifest → 6/6 → PASS. ARM64 iOS16 frontend parse, normalizer shell syntax and `git diff --check` → PASS. iOS-only SpriteKit assertions remain unexecuted on Linux.
