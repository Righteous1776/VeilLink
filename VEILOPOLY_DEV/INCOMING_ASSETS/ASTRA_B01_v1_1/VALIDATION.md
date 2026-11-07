# B01 v1.1 export verification

Command: `python sources/package_and_verify.py` → generated files and layout metadata checked → PASS

- 91 unique asset aliases: PASS
- 91 SVGs have viewBox and no baked text: PASS
- 91 PNGs have alpha and declared dimensions: PASS
- PNG and source SVG SHA256 matches: PASS
- nine-slice borders and text-slot bounds valid: PASS
- 15 landscape previews match @2x target canvas: PASS
- 15 layouts: board/panel non-overlap, HUD safe bounds and hero clip containment PASS
- capsule targets, auction overlays and action footer >=44pt in layout data: PASS

All 91 PNGs loaded uncompressed together: 37.48 MiB RGBA (excludes previews and Kimi scene). This is a size estimate, NOT GPU profiling. Production should load only the needed state skins.

PENDING / NOT RUN: Apple app rendering, GPU profiling, physical-device safe areas and hit testing, real keyboard and Dynamic Type behavior. This package has not been integrated into the game or accepted by Owner.
