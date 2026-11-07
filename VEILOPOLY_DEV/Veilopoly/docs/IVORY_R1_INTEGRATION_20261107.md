# Veilopoly Ivory R1 · Generated Art Integration / Codex Non-Overlap

Task: `VEILOPOLY-IVORY-R1-20261107`  
Baseline SHA: `08e33d486ee8d9c56d64ce1c79ea0ceaccc123f1`  
Branch: `dev/veilopoly` / authorized scope `VEILOPOLY_DEV/**` only.  
Style lock: **warm ivory parchment + muted antique gold + deep teal / classical Art Deco**.  
Source of truth: current `dev/veilopoly` Kimi K2 atlas, Codex `astraTile*`, `astraCenterCity`, `astraHouseGreen`/`astraHotelRed`, Astra B01 native interaction UI.

## Included original artwork and processing

Six images were generated in this conversation. Crop segmentation removes stray alpha artifacts outside connected artwork; individual image crops are downsampled with Lanczos and re-encoded PNG losslessly at the new pixel size. All 19 **derived sprites** are independently SHA-256 hashed and have known Git Blob SHA-1 identifiers. Six unmodified source images are included in the local recovery ZIP; their SHA-256 hashes are recorded in the JSON but not duplicated as 12-MiB raw sources in product runtime.

The authoritative `IVORY_R1_ASSET_LOCK.json` maps `VL-IVORY-R1-001` through `019` to the exact `Resources/ivoryR1*.png`, source image, crop dimensions, digest and override policy. No existing SpriteKit texture or Codex-generated binary was rewritten.

## Real runtime hookups (non-destructive and reversible)

- **Chance**: `UI.swift` existing card modal thumbnail chooses `IvoryR1Artwork.preferredCardAlias(isChance: true)` with `cardChance` fallback. Dynamic card description, native card face background, ACK, confirmation, and screen blocking all unchanged.
- **Chest**: same approach with `ivoryR1ChestCard`, falling back to `cardChest`. Dynamic game card effects remain from GameState.
- **Victory**: `BoardScene.swift` winner badge texture selects `ivoryR1VictoryBadge`, falls back to `kimiFxVictoryBadge`; the actual winner and display name still come from Engine and Astra settlement remains canonical.
- **Candidate resources** (no automatic overwrite): center inlay, ivory house/hotel, turn banner (has baked English text), 12 pictograms. These remain available through `IvoryR1Artwork.resourceURL(for:)`, but Codex's currently deployed art remains active.

## Why deliberately NOT replacing everything

The Codex work immediately preceding this task introduced `astraTileFace`, 10 specialized tile images, `astraCenterCity`, detailed `astraHouseGreen` / `astraHotelRed`, a matching SpriteKit composition and tests. This R1 does not duplicate that work or override it without visual A/B and iPhone tests. The new images are rendered art assets, not replacements for dynamic SwiftUI controls, tile hitboxes, underlying game rules, localization, or network synchronization.

## Checks and release boundaries

Local image validation: 19 PNGs decoded successfully with transparency, derived SHA256 and Git blob SHA-1 computed, 6 original source checksums retained. GitHub blob create API returned all 19 matching expected IDs. Registry has 19 unique aliases, 3 preferred runtime cases, 16 candidates, and zero collisions with Astra/Kimi aliases.

The new `IvoryR1Artwork.swift` pure Foundation registry is locally Swift 6.2.1 typechecked; this is **not** an Apple SDK / SpriteKit build. The new XCTest code source is added but actual iOS simulator, full XCTest and PNG RAM/performance tests remain pending.

DO NOT change `main`, VeilLink host/game hall, workflows, release, sign, IPA or protocol. A failed resource lookup falls back to the original visual; image generation alone never changes Engine state.