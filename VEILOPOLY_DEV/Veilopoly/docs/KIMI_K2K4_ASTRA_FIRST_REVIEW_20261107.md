# Veilopoly Kimi K2–K4 · Astra-first intake review (2026-11-07)

Task: VEILOPOLY-KIMI-ASTRA-INTAKE-20261107
Baseline branch: dev/veilopoly @ 698545f5b76b19c1cfc8266b1d1bad294946bc62
Input: Veilopoly_Kimi_Cumulative_20261106(1).zip
Input SHA256: 288f1465b13cf1e5081d350b3ce38dbad14cb29f3ca000e3cf98bae5b576c465

## Verified in the provided local archive
- ZIP CRC: PASS. SHA256SUMS: K1 23/23; K2 66/66; K3 11/11; K4 5/5.
- K2–K4 included asset manifest SHA256 digests: PASS.
- These checks prove archive integrity only, not independent third-party license provenance or iOS runtime compatibility.

## Conflict decisions (Owner: Astra wins)
- Astra B01: its 20 selected runtime PNG resources and five genuinely data-bound UI hero cards (BUY, AUCTION, TRADE, BANK, SETTLEMENT) remain canonical. Do not overwrite Astra interactive HUD/buttons/panels with Kimi screenshots.
- Existing Engine/AI/Net, RNG, ViewCommand and exactly-once ACK semantics remain canonical. Kimi board.json/cards.json do not become rule data.
- Kimi K1 atlas, cardback and buildClick assets were previously integrated. Do not import them a second time.
- K2: 2.5D board, four normalized tokens, three special tile icons and six effect/card-frame skins form 14 candidates under distinct kimi* aliases in KimiVisualAssetNames.swift. All remain disabled until independently accepted and actually copied to SwiftPM resources.
- K3: finance HUD screenshots are reference-only and may not replace Astra; star/chest/red/green house designs remain staging-only, especially where rules are undecided.
- K4: Day Felt light palette is defined in code but does not turn on or override Astra dark skins. Real light-mode accessibility and contrast acceptance is pending.

## Inconsistencies and gates
1. K2 historic MANIFEST still mentions pending token exports while the cumulative ZIP includes normalized PNGs; treat file integrity and design approval as separate states.
2. K3 historic MANIFEST mentions red dice, but actual final resources are red/green houses.
3. K3 420pt phone bank panel cannot be assumed safe in every landscape narrow-width layout.
4. K1 unresolved board/card rules remain unresolved; do not automatically adopt Kimi candidates.
5. Future optional asset import must be isolated under VEILOPOLY_DEV/INCOMING_ASSETS/KIMI_K2K4_20261106 with exact hashes, then selectively promoted to nonconflicting SwiftPM Resource aliases.
6. Do not claim Xcode compile, physical FPS/touch/VoiceOver, 500 completed AI games, or P5 VeilLink host integration without evidence.

## Status
This commit adds a *portable visual alias/theme contract and XCTest source*, not binary art and not live runtime rendering. Local Swift 6.2.1 standalone contract smoke PASSED. Exact branch SwiftPM tests, iOS compile/runtime, package resource staging and P5 integration remain NOT RUN.
