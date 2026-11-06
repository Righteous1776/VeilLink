# Kimi K1 intake / integration review · 2026-11-06

**Source:** Owner-provided `Veilopoly_Kimi_K1_v1.zip` (sha256: **7c0bae76b07c5da269e3727c3d76381527b416488c87b750e4281062f666cf25**).  
**Destination:** `dev/veilopoly` only, under `VEILOPOLY_DEV/**`.  
**Review mode:** additively stage original evidence; do not alter logical game rules or VeilLink product/main.

## Verified from supplied ZIP

- ZIP CRC passed (`testzip`); all 22 entries in `SHA256SUMS.txt` match their files.
- `ASSET_MANIFEST.json`: 35 entries, 26 marked `in-repo` and 9 marked `new-K1`; all 9 new asset SHA-256 values match the provided bytes.
- Three new PNG assets are available for standalone dev UI resources: `diceSheetWhite.png` (256×128), `cardChanceAlt.png` / `cardChestAlt.png` (140×190).
- `buildClick.ogg` is retained unmodified in intake and converted for iOS AVAudioPlayer into mono PCM 22,050 Hz `buildClick.wav`; new WAV was created from exact supplied audio.
- Corrected `diceSheetWhiteFrames.xml` under runtime resources to reference the actual image filename; the original XML is preserved unchanged in `INCOMING_ASSETS`.
- Four supplied `token*.svg` files parse as SVG but have *no* `viewBox` nor explicit width/height and contain 158 paths each; retain as **source only**, do not replace working PNG tokens until cropped/normalized exports are supplied and inspected.

## Important contract decisions

1. **Owner's new requirement supersedes K1 layout:** Veilopoly must occupy a *real full-screen landscape presentation* on iPhone and iPad. `previews/iphone-portrait-main.png` and `LAYOUT_SPEC.md` §3 are historical K1 proposal, **not the approved mobile runtime layout**. `VeilopolyUI/LandscapePresentation.swift` requests landscape via iOS 16 window-scene geometry API, `UI.swift` uses side-by-side landscape layout, with a two-button mini-program style capsule. Real rotation requires host iOS target orientation support (P5); iOS simulator/device tests still outstanding.
2. Kimi `sources/board.json`, `sources/cards.json`, `sources/rng.md` are **not authoritative rules**, only preserved proposals. Do not wire into GameFactory / GameState until Owner decides A01/A02 and discrepancies with `MODELING_SPEC.md`.
3. `docs/SPEC_QUESTIONS.md` proposes removing used jail cards from game, but `sources/cards.json.rules.jailCardReturnsToDeck` is `true` — direct contradiction; needs Owner ruling.
4. `docs/LAYOUT_SPEC.md` references `model/board.json` and `model/layout-projection.json`; actual package provides `sources/board.json`, with no standalone `layout-projection.json`. This is an unfulfilled source dependency, **not** a generated file.
5. All new assets claim Kenney CC0, but their item-level source URLs are only `https://kenney.nl/assets` (directory URL), not exact asset source or licensed provenance filenames. Source license **claimed, not independently verified**; keep as dev/experimental until traceability is complete.

## Integration boundary

No changes to `VeilopolyEngine`, `Move`, `Effect`, `GameState`, RNG, transport implementation, V8 schema, VeilLink `main`, version numbers, IPA or workflow configuration. Swift code may optionally play `buildClick.wav`; original K1 files remain unmodified as provenance.

## Acceptance state

- K1 upload/asset hashing: PASS.
- K1 staging in dedicated GitHub branch: pending until commit.
- Game assets as valid visible runtime skin: **partial only**; alternate card backs & dice sprite atlas have been copied for further UI work.
- Actual iOS 16 build, rotated full-screen presentation, safe-area capsule hit testing, animation ACK: **NOT VERIFIED**.
