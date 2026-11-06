# Kimi K2 delta / landscape full-screen scope · 2026-11-06

**Do not start over:** K1 files already received and hash-checked; current engine has 14 PNG + 12 WAV prior resources plus K1 supplemental textures. Please make a *delta* based on the actual branch `dev/veilopoly`, not a full replacement and not a new game engine.

## Priority 0 — correct K1 mobile layout

- Deliver **iPhone landscape** previews at **844×390pt and 852×393pt** reference safe areas, and an iPad landscape at approximately **1180×820pt**. Existing `iphone-portrait-main.png` is rejected as the mobile runtime design (reference only). No portrait-gameplay alternative.
- One genuine edge-to-edge full-screen scene: left whole 40-square board, right compact independently scrollable action panel. Safe areas and camera/board aspect must be preserved. Do not rotate a portrait screenshot sideways. Include smaller supported 16:9 landscape sizes and iPad Stage Manager behavior.
- Top-right two-target capsule: `•••` = more; circular dot-in-ring = exit. Each target min 44×44pt, divider, light surface, accessible names. **No PNG necessary** — programmatic SwiftUI icon already exists. Only supply visual metrics and style QA.

## Priority 1 — assets actually missing after K1

- 40-tile frame atlas / 8 color-group strips with prices/names as data-driven text, corners and railroad/utility/chance/chest/tax icons. Provide visually coherent **2.5D** board base/frame/felt, rather than the flat rectangular mock. The `board-layout.png` is a reference, not a directly usable board sprite.
- Four **separately exported** transparent token sprites/texture sheets from SVG sources, cropped to each token, with explicit `viewBox`, dimensions, pixel density, shadow/anchor/rotation data. Four original source SVGs currently have 158 paths each and no `viewBox`; do not pretend they can be loaded directly by SpriteKit.
- House×1–4 and hotel placement: slot offsets, oriented perspective for four board sides; shadow/highlight, and mortgage/ownership overlays. Where SwiftUI/SpriteKit draws an effect natively, provide timing/style specs only, not unnecessary static images.
- Animations: jail bars, GO reward, bankruptcy, trade chip/funds, card flip/card face/frame, purchase and building feedback. Supply **optimized atlases** with frame mapping that matches filename, texture dimensions, anchor, zPosition, shadow/hit-area specifications.

## Priority 2 — completed phase screen visual spec

- Landscape-optimized ROLL, BUY, AUCTION, MANAGE, TRADE, DEBT, CARD, SETTLEMENT and game-over states; all actionable controls ≥44pt without obscuring board or capsule.
- Dark and light themes (light "日间毛毡" is still open), icon contrast/VoiceOver/text size, special accessibility patterns, iPhone+ iPad screenshot previews, performance budgets ≤250 SpriteKit nodes and ≤60MB active textures.
- Existing `diceSheetWhite.png` + corrected runtime XML preserved, alternative card backs included. `buildClick.ogg` already converted to WAV in dev branch — do NOT resubmit the same files unless materially changed.

## Your manifest must include

`path`, `alias`, `sha256`, `bytes`, `pixel_dimensions`, `original_asset_url`, `source_license`, `K1_delta`, `target_scene`, plus textures/atlases metadata. Avoid generic directory-level links as the only provenance. Deliver ZIP to Owner for ChatGPT verification. Do not write game rules, transport, Swift Engine/AI/Net, or GitHub main.

## Pending Owner decisions (do not freeze independently)

- `sources/board.json` and `sources/cards.json` are only rule proposals. Used jail card's deck return contradicts K1 own `SPEC_QUESTIONS.md`. Confirm with Owner before writing card text into app logic.
- iPad face-to-face rotation mode and alternate card skins are not yet approved. No need to implement now.

## K1 intake audit correction — required in K2 metadata

Before the next submission, correct **two existing-file SHA-256 entries** in your `ASSET_MANIFEST.json`. Do not regenerate or resubmit binary resources solely to fix these records:

- `Sources/VeilopolyUI/Resources/die4.png`: exact repository SHA-256 `ae12bf1bd43d8f223417328d52a4ef6b691d596b4dd1a751daa35237cc1fe5a4` (K1 erroneously used `ae12bf1bd38d...`).
- `Sources/VeilopolyUI/Resources/mortgage.wav`: exact repository SHA-256 `f5d1be1f2aafb79711f4925d1671e81c3f9ee1b1c0955d89b0df26098c4b3b64` (K1 erroneously used `f5d1be1f2aafb79711f4925d1671e81c3f9ee1b1c095d89b0df26098c4b3b64`).

Detailed K1 evidence and original package are under `INCOMING_ASSETS/KIMI_K1_v1/`; canonical comparison is in `Veilopoly/docs/KIMI_K1_INTEGRATION_REVIEW.md`. The portable K1 atlas and resource tests are now in `VeilopolyUITests/K1DiceAtlasTests.swift`. **Do not repurpose K1 portrait preview for the mandated full-screen iPhone landscape composition.**
