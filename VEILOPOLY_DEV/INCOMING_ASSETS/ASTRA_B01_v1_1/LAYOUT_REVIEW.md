# B01 v1.1 · Layout review

Scope: independent source-coordinate inspection of `sources/build_assets.py`; no Apple runtime, touch dispatch, Dynamic Type, GPU, or device test performed.

## Geometry checked

- All three target canvases are landscape: 844×390pt, 852×393pt, 1180×820pt.
- Left board viewport and right operation panel have a 16pt gap; board remains a Kimi scene placeholder.
- Each more/exit capsule target is 46×44pt; footer actions are 44pt high.
- On 844×390pt, the 256×174pt hero occupies y=118…292; footer starts at y=308. On 852×393pt, the hero remains fully inside the right clip with additional 3pt space.
- On 1180×820pt, the scaled hero occupies y=124…374.125; the bank's third disabled product ends at y=690.125, above the clip bottom y=722 and footer y=738.
- Runtime values are separate text slots. Engraved-paper heroes use dark ink; the bank's two dark tiles use light text.

## Findings sent to producer

1. Phone HUD originally ends at H−12 while reference bottom safe inset is 22pt. Move it upward by 10pt or revise layout consistently, without overlapping the board.
2. BUY `property_name` originally uses [76,30,160,34], overlapping the static category label at baseline 41. Prefer [76,44,160,24].
3. AUCTION painted controls need program-owned hit overlays: minus [12,118,44,44], bid input [62,118,132,44], plus [200,118,44,44], in local 256×174pt hero coordinates. An image alone is not interactive.

Producer resolution: all three findings were fixed in the final generator/export. Phone HUD now ends at H−22; BUY name slot is [76,44,160,24]; AUCTION hit_targets_local_pt and layout bid_controls are included. The verifier checks safe-area containment, hero bounds and declared control sizes. This is local geometry validation, not device acceptance. Long property/player names, large monetary values, keyboard avoidance, actual safe-area insets and accessibility font sizes remain integration checks.
