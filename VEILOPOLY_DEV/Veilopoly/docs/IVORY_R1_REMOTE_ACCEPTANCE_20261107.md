# Veilopoly Ivory R1 — Remote resource acceptance

Task VEILOPOLY-IVORY-R1-20261107 | branch dev/veilopoly | baseline e0d77996e33e803599c03e4e4fee0cc23a613b52

19 original derived PNGs have been materialized on GitHub by a concurrent Agent and were individually read back and checked by SHA-1, alias, path and exact bytes. 19/19 matched, 2,293,866 bytes total. This commit does not reupload or overwrite any graphics.

Runtime hooked (3): ivoryR1ChanceCard and ivoryR1ChestCard through GameSessionModel UI card thumbnails; ivoryR1VictoryBadge through BoardScene winner adornment. Original cardChance/cardChest and kimiFxVictoryBadge are fallbacks. The dynamic card text, Engine winner, Astra transaction controls and animation acknowledgment remain unchanged.

Candidate resources (16): new center, house, hotel, banner and 12 icon sprites are addressable via IvoryR1Artwork, but do not replace Codex's astraCenterCity, astraHouseGreen, astraHotelRed, astraTileFace, or astraTile special pictograms.

New verify_ivory_r1_assets.py: standard-library read-only asset acceptance gate. It checks 19 stable IDs, expected activation set, SHA-256, Git Blob SHA-1, PNG IHDR dimensions, file bytes and target path. Standalone local run against extracted assets: PASS (19/19). Swift 6.2.1 registry typecheck with Bundle.module test stub: PASS.

Not run: iOS Xcode build, complete XCTest, SpriteKit rendering, mobile UI layout, phone GPU/memory tests. Authorized VEILOPOLY_DEV/** only. No main, IPA, release, GitHub Actions, protocol, or P5 transport modification.
