# Astra B01 v1.1 · runtime subset integration (2026-11-07)

Origin: `VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/`.
Only 13 selected PNG runtime skins are copied by **referencing identical Git blob SHA**; no raster conversion, no rebuilt images, no overwrite of Kimi/K1 assets. Original metadata, full SVG sources, 15 previews and 91 aliases remain unchanged at the intake path. The source SHA-256 is from the Astra-verified manifest, not an independently performed hash computation in this runtime.

```json
[
  {
    "alias": "astra.button.primary.normal",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/components/button-primary-normal.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraButtonPrimaryNormal.png",
    "sha256": "c9a00db01730cb40061345651f1abe34ffc294845d67655525a20a8efdb38ab0",
    "gitBlob": "06b3dc2675cdaa346a7b8515d551250a04627ae1",
    "bytes": 4895,
    "dimensions": [
      480,
      96
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.button.primary.pressed",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/components/button-primary-pressed.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraButtonPrimaryPressed.png",
    "sha256": "c411238ee22de3fda9682ecc0f7701e718f40de6546b41de216489505ab48c91",
    "gitBlob": "54a1ed23031156952fd309edb913f08c9aa91fff",
    "bytes": 2118,
    "dimensions": [
      480,
      96
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.button.primary.disabled",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/components/button-primary-disabled.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraButtonPrimaryDisabled.png",
    "sha256": "8918785b001b22addd3f47a3dbba9378bfae0de85270d47e1c420494ea0db935",
    "gitBlob": "6a4d7669072a7112a4a1445853d9d37e3d7f7676",
    "bytes": 2783,
    "dimensions": [
      480,
      96
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.panel.glass",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/panels/glass.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraPanelGlass.png",
    "sha256": "9106fc0aa019471501303c135a077f427146fe5c5b838311a6d7669b4ba14b91",
    "gitBlob": "e7d677eedd58418f0e2b17b030d36053112685fd",
    "bytes": 37237,
    "dimensions": [
      640,
      640
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.panel.action",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/panels/action.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraPanelAction.png",
    "sha256": "9c8c17a7508e450cb5e76dec106ddb334804e646d2703c73e9c7813d823bf8e7",
    "gitBlob": "8a5cab130cc771c380f45bf490b20f80db480688",
    "bytes": 37234,
    "dimensions": [
      640,
      640
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.feedback.error",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/components/feedback-error.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraFeedbackError.png",
    "sha256": "1b6d0a9dab276901a44f730845ad65998a126d5319fdc766984f9182c16b9648",
    "gitBlob": "29eea315a0d8e805a46691be0ba9fb349bc2eddd",
    "bytes": 3650,
    "dimensions": [
      480,
      96
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.feedback.positive",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/components/feedback-positive.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraFeedbackPositive.png",
    "sha256": "5d4472674ab9ba3a6aeb6df230f16aaccf4046a3065d2487799498d8c489dbdf",
    "gitBlob": "0a1241daac5eb89cfe1b7b8a1800630e7aa5b4f8",
    "bytes": 2362,
    "dimensions": [
      480,
      96
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.card.face",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/panels/card-face.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraCardFace.png",
    "sha256": "116f90ca7e2c1f3736d4c950c04259c5a0063d3914a1eab4ed6ce575c5524154",
    "gitBlob": "8aad39619b364d30406b705c22de68414157efb0",
    "bytes": 35795,
    "dimensions": [
      560,
      720
    ],
    "resize": "nine_slice"
  },
  {
    "alias": "astra.hero.buy",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/tabletop/hero-buy.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraHeroBuy.png",
    "sha256": "c5be013fe792c878d016bf1cf2cf474c584dc99b5a0a48bc26cfc84d3c8336ec",
    "gitBlob": "9f68cca43cd27d76398b86b0aa2dfb4d4edc789c",
    "bytes": 30804,
    "dimensions": [
      512,
      348
    ],
    "resize": "aspect_fit"
  },
  {
    "alias": "astra.hero.auction",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/tabletop/hero-auction.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraHeroAuction.png",
    "sha256": "aee1cba27c2a60a17cf09145d6b35409eab5f7dce9f594ead26b66b420abeb68",
    "gitBlob": "0708c7c5ffe0523bdba5a8235306740d1cc348b3",
    "bytes": 28886,
    "dimensions": [
      512,
      348
    ],
    "resize": "aspect_fit"
  },
  {
    "alias": "astra.hero.trade",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/tabletop/hero-trade.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraHeroTrade.png",
    "sha256": "bfc4103c3adb36d5b745ef17378d791e3d310b1b1a1902bdbd3665e833f035b1",
    "gitBlob": "e83510653c5b808fbbb25825d168c5030f27abb5",
    "bytes": 22975,
    "dimensions": [
      512,
      348
    ],
    "resize": "aspect_fit"
  },
  {
    "alias": "astra.hero.bank",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/tabletop/hero-bank.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraHeroBank.png",
    "sha256": "b0ac2e5984860deb20830c996db32ca0aef3d8b0125deba0e1d128748fe3dfc1",
    "gitBlob": "ce61ece260677f210c576d8b291806fdeddd8b1a",
    "bytes": 32364,
    "dimensions": [
      512,
      348
    ],
    "resize": "aspect_fit"
  },
  {
    "alias": "astra.hero.settlement",
    "from": "VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/ui/tabletop/hero-settlement.png",
    "to": "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/astraHeroSettlement.png",
    "sha256": "5946cd37bc9897e78f633390515943c98b5e248f59d29e66f007c600baf51c5c",
    "gitBlob": "c43d795d9d079604660b9b03880c78eca99ae799",
    "bytes": 33384,
    "dimensions": [
      512,
      348
    ],
    "resize": "aspect_fit"
  }
]
```

## Activation boundary

- First pass: actionable button skin, right-side action panel, compact HUD cards, event/error feedback, readable card-modal and data-bound BUY/BANK/SETTLEMENT hero cards.
- AUCTION/TRADE hero PNGs are **staged but not drawn** until real +/- numeric hit regions and offer/request input overlays are wired. Their painted controls must never be used as inert buttons.
- Dynamic amounts, property names, player names and game outcome are rendered by SwiftUI; no screenshot is used as an interactive screen.
- Do not process all 91 textures at launch. Only 13 referenced PNGs are included in the Swift Package; full intake previews remain outside `Resources/`.
- Avoid resizing hero art as a nine-slice: fixed 256×174pt card with explicit local text slots. Buttons use [top=12,left=42,bottom=12,right=12] pt insets; panel [24,24,24,24]; card [88,26,26,26].
- Apple SDK compile, landscape keyboard, VoiceOver and touch acceptance remain pending. No modifications to Engine/AI/Net or VeilLink product `main`.
