# ECLIPSE Original Orange — Screenshot reference and validation

User supplied three iPhone screenshots (2026-11-14): `IMG_6854.jpeg`, `IMG_6855.jpeg`, `IMG_6856.jpeg`.

Approved visual language:
- VeilLink native **orange** on toolbar, model avatar orbit, difficulty/deep-search toggle, last-move ring, sliders, status and action links.
- Existing black ambient background with subtle particles; **deep grey** cards, not entirely flat pitch-black blocks.
- Original warm dark brown 15×15 board texture; black/white stones, silver grid, orange last move.
- Black ECLIPSE code console with subtle orange border and silver/orange text.
- Red reserved for errors; muted amber reserved for caution.

R17 changed dominant accent to green; R17.1 corrects all Gomoku-only accent uses to `VeilTheme.gold`, preserving the user's UI theme rather than hard-coding a new orange RGB value. UI/engine logic unaffected.

Status: Swift syntax and palette regressions tested locally. Xcode full typecheck and iPhone screenshot must be verified by Governor.
