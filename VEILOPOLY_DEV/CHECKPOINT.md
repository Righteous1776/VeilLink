# Veilopoly Development Checkpoint — 2026-11-06

## Generated center city inlay — 2026-11-07

- Task `VEILOPOLY-ART-INLAY-005`, baseline `0978834e5120973440c9313a3c94c5b354753aa7`. Owner authorized actual image generation and local texture composition. Direct source-layer inspection identified sparse center art and flat token/building materials; transparent original emblem/frame were correctly inspected with alpha composition, not mistaken for solid images.
- Generated transparent miniature financial-city art with the OpenAI image tool. Original 1254px / 1,855,374 bytes and provenance retained under `INCOMING_ASSETS/ASTRA_CENTER_CITY_R1`; runtime `astraCenterCity.png` is 512px RGBA / 222,089 bytes / ~1 MiB decoded. SHA-256 recorded for both in the manifest.
- Optional z=3.5 city inlay replaces the center emblem only when present, keeps original emblem fallback and does not touch tiles, labels, tokens or interactions. Full 448pt square bounds do not overlap any of the 40 rotated tiles. Day/night source-layer composition previews visually inspected; they are not device screenshots.
- Original baseline plus patch: Swift 6.2.1/Linux full XCTest 141/141 PASS, art/resource tests 5/5 PASS, iOS16 ARM64 frontend grammar parse PASS. Actual Apple rendering/type-check and GPU behavior remain PENDING. Audit, remaining modeling limits and preview command: `Veilopoly/docs/CENTER_CITY_ART_REPAIR_20261107.md`.
- Synced additively onto concurrent remote save/resume baseline `69acec5`; full Linux XCTest repeated: 154/154 PASS, 0 failures. Art file hashes and original source payload retained unchanged.

## Unified gameplay composition — 2026-11-07

- Task `VEILOPOLY-GAME-COMPOSITION-004`, baseline `f98b29a4223c0b3fd3acb961b6a217e273103e8b`. Source/art integration stays inside the existing dedicated branch live lane. Existing Kimi board and Astra controls are preserved and connected through one GameState/reducer/render ACK pipeline.
- Four management sections replace the long property→trade→bank→stock stack; turn completion remains pinned. Board taps reveal selected property details; required decisions open after ACK. Real Kimi token art appears on Astra player skins and the collapsed operation entry. Chance/chest modal uses the correct deck.
- Added reducer-derived operation availability, localized rejection text, bank maturity/cash cues, reset of stale trade drafts, genuine editable cash counteroffers retaining assets, shared book-net-assets summary and stock cash FX routing. Historic experimental finance/printed rules remain reference code; no contradictory ruleset activation.
- Added five portable integration tests plus one guarded iOS command-routing test. Portable suite includes a complete property/bank/stock/trade/end-turn replay with identical state hashes. Details and Apple acceptance checklist: `Veilopoly/docs/UNIFIED_GAMEPLAY_COMPOSITION_20261107.md`.
- Linux Swift 6.2.1 build PASS; portable composition tests 5/5 PASS; full XCTest 139/139 PASS (0 failures), including bounded 500-seed AI smoke and 20 exploratory long games; iOS16 ARM64 frontend grammar parse PASS. Apple SDK type-check, rendered visual/touch/VoiceOver/frame-time acceptance remain PENDING. No main, P5 host, workflows, schema/protocol, signing or release changes.

## Stock terminal V3 continuation — 2026-11-07

- Task `VEILOPOLY-STOCK-MARKET-UI-003`; baseline `f5f9747` on `dev/veilopoly`, scope `VEILOPOLY_DEV/**`. Stock terminal changes coexist with the latest Kimi tile-mask/day-theme work; no overlap in BoardScene or art resources.
- Added long-press chart inspection and VoiceOver point adjustment, recent manual execution receipts separated by player, persistent last-order errors, exact disable reasons including sale cash cap, and zero-quantity maximum behavior. Session receipts retain 40 entries / display latest eight for the current player and reset with the session.
- Lifecycle correction: foreground-only cancellable ticker; price-only ticks skip SpriteKit display and preserve order errors. Reduce Motion applies to price and holdings animations.
- `swift test --jobs 2 --filter 'StockTerminalStateTests|StockMarketTests'` → 15 passed → PASS. `swift test --jobs 2` → 134 passed → PASS, local Linux Swift 6.2.1. `swiftc -frontend -parse -target arm64-apple-ios16.0` for changed SwiftUI files → success → PASS for grammar only.
- Apple SDK type-check, chart gesture vs drawer scroll, VoiceOver, lifecycle on device, haptics and visual density remain PENDING. No main/P5/workflow/release/protocol/schema changes. See `Veilopoly/docs/OFFLINE_LIVE_STOCK_MARKET_20261107.md` for behavior and verification boundaries.

**Branch:** `dev/veilopoly` (from `main@ccafebab147e069fbabfff579dbf323b0d54f191`). This is a parallel **development lane**, not the product main branch.

## GitHub source import — COMPLETE for standalone P1–P4

- `1f270948f429af06ec2a1176d57beac1c728adea`: 43 Swift Package text files (Package.swift, README, Engine/AI/Net/UI source, test files, game/model/render specs, validation/license docs).
- `a356d9b9741e25214fac63ee77a376e7b8cfb352`: 26 licensed resource blobs = 14 PNG and 12 WAV (225,915 bytes), plus `Veilopoly/docs/RESOURCE_INTEGRITY.json` with original SHA-256, size and Git blob SHA.
- Earlier branch commits had already introduced this isolated work area, Kimi handoff, permissions and an initial test-file import. The above commits finish the source migration without modifying `main`, transport, Protocol 4, VLGM1 or SQLite V8.
- The newer source baseline is `Veilopoly_P1-P4_Full_Source_20261106.zip`; the five legacy `Veilopoly/INBOX/*` handoff files are superseded by the branch-local `GOVERNANCE.md`, `COLLABORATION.md` and `KIMI_HANDOFF.md` and were not duplicated.

## Verified locally, NOT on GitHub CI / iOS SDK

- `swift build --jobs 2`: **PASS**, Linux Swift 6.2.1.
- `swift test --jobs 2 --skip 'LongSimTests|AutoplayTests'`: **29/29 PASS**.
- `swift test --jobs 2 --filter 'LongSimTests|AutoplayTests'`: **2/2 PASS**.
- Thus **31/31 checks** passed in two local selections against the same imported source state; earlier whole-suite log also reports 31 passed. Linux conditionally excludes SwiftUI/SpriteKit runtime compilation/behavior.
- AI smoke: **500 seeds × max 500 moves** ran without illegal engine moves; **0/500** naturally completed within that short bound. Exploratory **20 seeds × max 6000 moves**: 14 completed, 6 capped. Do NOT claim 500 fully finished games.
- Historical engine coverage evidence: 732/745 lines = **98.26%** for selected Engine+AI tests; no independent coverage run against this exact GitHub branch commit.
- iOS 16 Xcode build, simulator/physical device, FPS, touches, sound and animation ACK **NOT VERIFIED**.

## Next engineering gate

1. Run the checked-in package from the `dev/veilopoly` branch in a clean macOS/Xcode iOS 16 SDK environment and full XCTest inventory.
2. Validate SpriteKit command queue: 1.2s dice, 150ms/tile, skip once and only once, phase ACK, L0–L7, touch and sound.
3. Resolve rules ambiguities in `Veilopoly/docs/SPEC_DECISIONS_REQUIRED.md` with Owner; sample cards and unresolved boundaries remain non-production.
4. Accept Kimi visual K1 package with license/alias/hash and verify mapping without touching Engine logic.
5. After P1–P4 acceptance, request separate authorization for P5 VeilLink adapter / game hall / product release.

**Coordination:** https://github.com/Righteous1776/VeilLink/issues/6

## Post-import P4 UI hardening (source-only)

- Commit `f03583a6252cd1df48c0a7b713d37692bbd84d59` updates `VeilopolyUI/UI.swift` so `animating` is `@Published` (SwiftUI action panel refreshes when the animation queue ACK completes), keeps `configuredHumanCount` through Restart, re-drives an AI-only session after Restart and prioritizes the animation-in-progress panel.
- Local Linux `swift build` and 29 selected non-AI XCTest checks PASS after patch; **the iOS-only SwiftUI source is conditional and did not compile in Linux**, so P4 iOS/Xcode behavior is still unverified.
- Next gate remains macOS/Xcode iOS 16 Simulator and device validation with real SpriteKit frames and ACKs.

## P4 landscape-fullscreen / capsule UI checkpoint — 2026-11-06

- Commit `a9cf562dad13457a42d42bbe47f802cf9af592da` adds true landscape screen composition: full-screen SwiftUI cover, iOS 16 UIWindowScene orientation request + best-effort restore, 40-tile board non-scrollable left with independent action sidebar right, and portrait-orientation failure explanation.
- Right-top two-segment capsule is SwiftUI vector (no additional PNG): `•••` More, circular Exit; 46×44pt independent targets; More opens Restart/Game Info, Exit confirms and calls provided exit/dismiss.
- New `VeilopolyLandscapeLayout` pure layout constants, `VeilopolyUITests/LandscapeLayoutTests.swift` and `Package.swift` test target.
- Source contract and future P5 host requirements: `Veilopoly/docs/LANDSCAPE_PRESENTATION.md`.
- Existing resource inventory and Kimi pending-asset audit: `Veilopoly/docs/ASSET_GAP_REGISTER.md`. Kimi already owns some unsubmitted modeling; those items remain **PENDING_EXISTING_WORK_REVIEW**, NOT confirmed missing.
- Linux local `swift build --jobs 2` and selected `swift test --jobs 2 --skip 'AutoplayTests|LongSimTests'` **PASS (34 tests, 0 failures)**; `LandscapeLayoutTests` alone **5/5 PASS**. SwiftUI/UIKit iOS code compiled conditionally out on Linux; iOS SDK, physical rotation, safe area, capsule, SpriteKit and host app P5 still **UNVERIFIED**.
- P5 real VeilLink entry and host Info.plist/navigation orientation support remain outside this branch's write authorization. Do not claim orientation rotates actual VeilLink build before P5 integration.

## Kimi K1 parallel visual admission + P4 follow-up (2026-11-06)

- Received and verified Owner-supplied `Veilopoly_Kimi_K1_v1.zip`. ZIP CRC and its 22 SHA256SUMS entries all passed. Staged **23 original source/preview/asset files (22 individually checksummed in SHA256SUMS.txt; the 23rd is SHA256SUMS.txt itself)** extracted (no opaque ZIP) under `INCOMING_ASSETS/KIMI_K1_v1/`; imported **3 optional PNG runtime resources**, corrected atlas XML metadata, and converted buildClick OGG to 22,050 Hz PCM WAV. Parent staging commit: `38f8c90bb2b60b39dbf4905d305937390033712e`.
- Kimi 9/9 new asset SHA256 claims match payload, but two **existing** manifest entries differ from actual repo hash: `die4.png`, `mortgage.wav`. Exact evidence in `Veilopoly/docs/KIMI_K1_INTEGRATION_REVIEW.md`; original Kimi manifest remains untouched. Kimi needs to correct these metadata entries in K2 (no need to re-create binaries).
- K1 `LAYOUT_SPEC.md` uses a portrait iPhone main screen; **superseded** by Owner's full-screen landscape requirement. K2 priorities and missing 2.5D outputs listed in `Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md`.
- SwiftUI landscape fullscreen + WeChat-style More/Exit capsule were already implemented in the isolated development UI (commit `a9cf562dad13457a42d42bbe47f802cf9af592da`). K1 follow-up now uses supplied dice sheet atlas with six pure-coordinate UV lookups and existing-six-PNG fallback; plays converted `buildClick.wav`; added 3 portable resource/atlas tests, in code commit `1ecaf8b09af5d0a1c900453b9eae4bbe414f1e8b`.
- **Linux Swift 6.2.1:** `swift build --jobs 2` PASS; `swift test --skip 'LongSimTests|AutoplayTests'` **37/37 PASS**; `swift test --filter 'LongSimTests|AutoplayTests'` **2/2 PASS** before the final resource-existence assertion was added (engine/AI unchanged); K1 three new tests also PASS after that addition. All claims relate to local Linux, not branch CI or Apple SDK. AI 500 seeds remain bounded, not 500 completed games.
- **Unverified and gated:** iOS 16 SpriteKit/UIKit/SwiftUI target compile, scene rotation / true full-screen, active capsule 44×44pt hit zones, device safe area, animation ACK, real touch/audio, P5 hosting, main merge and IPA. No product transport, Protocol 4, VLGM1 or SQLite V8 changes.

## Kimi K1 formal intake + dice atlas integration (2026-11-06)

- Owner-supplied `Veilopoly_Kimi_K1_v1.zip` passed ZIP CRC and all 22 supplied SHA-256 checks. 35 manifest entries: 26 pre-existing resource references + 9 new K1 assets. Original 23 files preserved in `INCOMING_ASSETS/KIMI_K1_v1/`; no ZIP archive committed.
- New runtime items: `diceSheetWhite.png`, `diceSheetWhiteFrames.xml`, `cardChanceAlt.png`, `cardChestAlt.png`, `buildClick.wav` converted from the original OGG. Legacy PNG/WAV names were retained. See `Veilopoly/docs/KIMI_K1_INTEGRATION_REVIEW.md`.
- K1 dice atlas code was integrated on the dedicated branch with `VeilopolyDiceAtlasMap.swift`, `K1DiceAtlasTests.swift`, and `BoardScene.swift` using a six-frame SpriteKit UV map and pre-existing die PNG fallback. These three files plus the atlas PNG matched the checked-in Git blob hashes during local review.
- **Portable local tests against the corresponding source snapshot:** Linux Swift 6.2.1 `swift build --jobs 2` PASS; `swift test --jobs 2 --skip 'LongSimTests|AutoplayTests'` 36/36 PASS; `swift test --jobs 2 --filter 'AutoplayTests|LongSimTests'` 2/2 PASS. AI pressure: 500 seeds each capped at 500 moves (0 naturally finished, no invalid moves); 20 longer seeded games (14 finished / 6 capped). This **is not a GitHub CI run of the exact branch tip**, and the iOS-only SwiftUI/SpriteKit code remains excluded on Linux.
- K1 outstanding discrepancies: K1 phone portrait layout superseded by Owner's landscape requirement; 4 SVG token sources lack usable canvas bounds; K1 XML asset filename corrected only in runtime copy; manifest hashes for `die4.png` and `mortgage.wav` have typos; exact file-level third-party asset provenance needs confirmation; jail-card deck return contradictory within K1.
- Kimi next phase: `Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md` and refreshed `ASSET_GAP_REGISTER.md`. `KIMI_HANDOFF.md` points to K2 without asking for duplicate K1 work.
- P5 remains **NOT AUTHORIZED**. Actual VeilLink full-screen rotation requires host Info.plist/UIViewController support; no iOS Simulator/device landscape, VoiceOver, touch, audio, frame-rate or ACK acceptance has occurred.

## P4 Render ACK one-shot gate (2026-11-06)

- New `VeilopolyUI/RenderCommandAckGate.swift` + five `RenderCommandAckGateTests.swift` XCTest cases: exactly-once completion tokens prevent stale/duplicate/fast-forwarded SpriteKit callbacks from advancing a later ViewCommand. Commit `ac06449da20d65221e2ed371ea609b65cfed9add`.
- `BoardScene.swift` now registers `tileFx` terminal state before a potentially synchronous nil-node ACK; commit `a417901dbb66878a7455a69cc2cc101ccee8b5cc`.
- Swift 6.2.1/Linux local `swift build` PASSED; 42 non-AI XCTest PASSED; separately 500-seed AI smoke and 20-seed long-run tests PASSED (44 unique tests total). K1 dice atlas + landscape + ACK targeted tests 13/13 PASSED, overlapping with the 42.
- The 500-seed smoke uses **500 move cap**; 0/500 finished naturally. The 20-seed longer sample finished 14/20 within 6,000 moves.
- `swiftc -frontend -parse` passes grammar only; real iOS SwiftUI/SpriteKit type-check, orientation, texture drawing, touch and ACK race on iOS remain **unverified**. No workflow dispatched.
- Exact test evidence and device checklist: `Veilopoly/docs/P4_ACK_GATE_VALIDATION.md`. No Kimi asset or Engine/Net mutation in this change.


## Owner banking / printed tabletop research lane (2026-11-06)

- Owner provided two photographed rule references (handwritten savings/loans/investments and printed property banking table game). Photos are not put into source.
- Source-derived specifications and conflict register: `Veilopoly/docs/OWNER_FINANCE_AND_TABLETOP_RULES_20261106.md`.
- Implemented in the **standalone pure Swift experimental layer**, not existing GameState: `FinanceExpansion.swift` with deterministic borrow quotes, 4 rate tiers / land collateral caps, configurable savings products, simulated managed/venture/stocks outcomes, period advancement, no-stake dice challenge, seededRNG-only outcomes, replayable move log; `PrintedTabletopReference.swift` with alternative Start salary, 8-star cycle, injected elapsed-time cash leadership.
- The printed reference's GO +1000 (not on exact arrival) and hotel after two houses **conflict** with classic GO +200 and four-house build. No classic game rules or state hashes changed.
- Verification on local Swift 6.2.1/Linux source snapshot: `swift build --jobs 2` PASS and **`swift test --jobs 2`: 55/55 PASS, 0 failures**, including 11 new finance/tabletop tests and the two original long AI tests. Git blobs of six new files were cross-checked with local source hashes. This is NOT iOS SDK/VeilLink product CI proof.
- Remaining hard gates: Owner approves deposit brackets/maturity, loan overdue & collateral 4+, product dice payout schedule, star tie/build effects, and separate classic/printed mode entry; followed by versioned integration with GameState, standardized Moves/Effects, AI, UI and snapshot replay.
- Kimi visual follow-up: `Veilopoly/docs/KIMI_FINANCE_HUD_REQUEST_20261106.md`. P5 integration remains NOT AUTHORIZED.


## Unified rules · finance AI regression (2026-11-06)

- Owner directed **one Veilopoly ruleset**, not separate Classic/Bank modes. The previously merged canonical banking reducer is in `VeilopolyEngine`; this lane only extends AI spending behavior without creating a second ledger or random source.
- `30a0d6b28b345b5b17dce6cdc8c9db239adc5d2e` adds `VeilopolyAI/FinancePolicyAdvisor.swift` and hooks existing AI purchase/auction/build/bail cash-reserve checks to **known next-turn loan obligations**. Reports are pure integer functions: reserve, due now/within horizon, shortfall, authoritative RuleJudge next action.
- `FinancePolicyAdvisorTests.swift` (5 tests) includes **320 seeded no-mutation/no-external-RNG cases**. `CanonicalFinanceHashTests.swift` (2 tests) verifies enum-key payout dictionary insertion order cannot change `StateDigest`, plus reject/no-mutation.
- `Veilopoly/docs/FINANCE_AI_RULE_REGRESSION_20261106.md` documents policy semantics and Kimi animation boundary.
- **Local Linux snapshot test:** Swift 6.2.1 `swift test --jobs 2` **53/53 PASS**, of which the original AI 500-seed test is capped at 500 moves (1 naturally finished within bound); these numbers are from a local workspace containing separate uncommitted parallel star/rules edits, so **this is not an exact GitHub HEAD/CI certification**. The new seven targeted tests passed in the isolated workspace.
- P4 Apple SDK/SwiftUI/SpriteKit, IPA, P5 host, Protocol 4, VLGM1 and SQLite V8 remain unchanged/unverified. No trained neural network or ML weights claimed; 'rule-model training' refers to deterministic regression/self-play evaluation.


## P3/P4 state consistency and repayment safeguard (2026-11-06)

- `8efabadfd8402412e88fc11cc49c3d2df5a299f7` hardens 3 existing modules, adds 2 test suites (8 test cases) and `Veilopoly/docs/ENGINE_INTEGRITY_HARDENING_20261106.md`.
- `ReplicaClient.resync`: reject stale snapshots (would roll back already applied moves), foreign seed/session, noncontiguous move logs and inconsistent seq/hash. Same-sequence recovery is intentionally supported; future P5 must authenticate the host before snapshot acceptance.
- `IntegratedBanking.validate`: bound historical savings yield, loan interest/term/maturity/amount, investment kinds/periods and record IDs to prevent corrupt values from reaching arithmetic.
- `VeilopolyEngine.apply`: post-validate all player cash bounds, financial ledger integrity, and bank inventory (0…32 houses, 0…12 hotels) **before** committing a move. Failure keeps original GameState and RNG unchanged.
- **Local test evidence:** Swift 6.2.1/Linux `swift test --jobs 2` **61/61 PASS, 0 failures**, including original AI bounded tests and the 8 new regression cases. This is the previous local working tree with parallel, not-yet-promoted edits, **not a clean checkout of the exact GitHub branch HEAD**. No hosted CI/iOS SDK run is claimed.
- Kimi visual assets, GameTransport P5 adapter, Protocol 4, VLGM1, SQLite Schema V8, VeilLink main, IPA/workflows untouched.

## P4 UI/UE & procedural VFX V2 (2026-11-06)

- Source commits `d08e74fea8edaf199f618160da87f45eb1b4a57f`, `aa229b7131fe987cc2949e86da17c33cc0b4a420`, `695e4fa57ba6ec1dbe319460f3bebe8eb4bf3f36`, `1bab79e9a625f5e41c51d4b854df812da2955a77`, `594ba969c3c05c8c0a9d9bb175bccdc69f92d2e6`, `38c03a531c0d9499fca3241aea53102debf15020`.
- UI interaction: an explicit 44pt action standard and skip button, 40-tile inspector with scene-local touch hit-test + yellow focus marker, prominent last-Event HUD, error feedback, modal card reading gate (human dismiss vs AI autoplay), and Reduce Motion terminal states.
- Procedural art placeholders: board tile captions, mint current-position marker, pulse ring, pawn-local cash float, readable turn/bonus/win banner, per-scene texture cache; no Kimi assets modified.
- Portable UI tests **8/8 PASS** in local Swift 6.2.1/Linux (`CardRevealGateTests` 5, `VeilopolyEventFeedbackTests` 3). Extended general test run was stopped before completion due to long deterministic tests and does NOT establish a new full-suite PASS.
- Visual and interaction handoff: `Veilopoly/docs/P4_INTERACTION_AND_VFX_V2_20261106.md`. iOS 16 Xcode/SpriteKit/SwiftUI type-check and physical graphics/touch acceptance **NOT VERIFIED**.
- Live branch remains isolated from VeilLink product main, transport, SQLite V8, workflows, IPA; P5 requires separate permission.

## Astra B01 v1.1 — first runtime UI wiring (2026-11-07)

- Source asset intake `b2e200c1b7ea68f42a534ea475ac60972de0367d` holds **91 Astra aliases** (90 runtime/1 reference), 15 iPhone/iPad landscape previews, SVG/PNG editing sources and manifest; no Swift runtime integration in intake commit.
- `32249410a6613ee25efd856693bbe996c9519305`: 13 selected B01 PNGs copied into `VeilopolyUI/Resources/` by identical Git blob SHA; 268 KiB compressed sum according to Astra manifest and ~8.94 MiB fully decoded RGBA estimate (not actual GPU measurement). Full 91 alias kit remains in `INCOMING_ASSETS`, not Swift Package resources.
- `107896e32b402141b8e40eefd0a74a2903b7db00`: `AstraB01AssetNames.swift`, `AstraB01Skin.swift`, `AstraB01AssetRegistryTests.swift`, `UI.swift` skin wiring. LIVE: button normal/pressed/disabled, action/glass panels, feedback/error backgrounds, readable long card modal, data-bound BUY/BANK/SETTLEMENT hero tickets. Auction/trade hero PNGs are staged only, as their painted +/- and amount fields cannot be presented as dead controls.
- Strict fallback: existing engine state, SwiftUI Button callbacks, numeric fields, Player cash, rent, winner and bank balances remain authoritative. No static preview art is rendered as a game view. No Kimi 2.5D/character/building assets or P5 host app were modified.
- Static repo audit: 13/13 runtime image aliases have package resources and byte-identical Git blob SHA to the checked-in Astra source; existing manifest nine-slice insets are within logical bounds. The PNG selection is deliberately limited for compact iPhone memory.
- `Veilopoly/docs/ASTRA_B01_RUNTIME_INTEGRATION_20261107.md` documents integration and acceptance risks. **Xcode iOS compile, artwork brightness, safe areas, keyboard, Dynamic Type, VoiceOver, touch hit-testing and GPU timing NOT VERIFIED.** No hosted CI/IPA run was started.


## Astra B01 second-stage concurrent UI intake and regression fix (2026-11-07)

- `c30d192ee9ec...`: 7 extra textures were staged by another scoped UI Agent (secondary button normal/pressed/disabled + current/jailed/bankrupt/normal player HUD), bringing selected B01 runtime PNGs from **13 to 20**. No Kimi textures or game Engine were overwritten.
- `b5669cc5c95ad075f2892415308ea73f2f51dfa5`: uses explicit @2x `UIImage` scale via cached `AstraB01Artwork.image` for pixel-to-point correctness; enables secondary action skins and dedicated four-player status skins. This was a concurrent branch change, preserved rather than overwritten.
- `cc0958a6e9987b9e9ec20fd62b49e6d42b4f1cc9`: card/financial UI quality follow-up on current source: prevent Astra feedback background's baked icon from overlapping a duplicate SF Symbol, show "余额不足", disable BUY when available cash is below cost, and disable a bid below or equal to current high bid.
- `d6662637d4678a162ed048a68a0f606d7098e32c`: fix a definite stale test assertion expecting 13 unique names after the asset set grew to 20; compare unique count to registered runtime count.
- Static Git tree audit confirms **20/20** imported B01 PNG aliases have corresponding Resources paths with blob SHA identical to Astra intake originals; per-manifest compressed PNG total **333,980 bytes** and decoded RGBA estimate **10.21 MiB** if all decoded at once (not device GPU telemetry). Nine-slice source cap insets remain within each original logical asset size.
- The broader 91-alias Astra package still lives in `INCOMING_ASSETS/`, and **AUCTION/TRADE hero controls remain staged but not actively overlaid**. Kimi B02 and P5 are not part of this change.
- No exact branch-hosted XCTest, Xcode iOS build, safe-area, haptic, keyboard/VoiceOver, GPU/frame-time, or IPA verification was performed in this turn.

## Offline live stock market — implemented and locally verified (2026-11-06)

- Task `VEILOPOLY-STOCK-MARKET-001` was implemented on `dev/veilopoly` from baseline `27d6938955f4b97ed28e1358c7e9594b6ef16688`. It is a wholly local game simulation: five fictional instruments, seeded common/idiosyncratic movement, regime changes, mean reversion, bounded shocks, ±10% session limits, short halts, volume and a bounded 96-point tape. It performs no network request and represents no real security or recommendation.
- New authoritative moves/effects cover market tick, buy and sell. Whole-share orders use cash, 0.50% fee with ¥1 minimum, weighted cost basis, realized/unrealized P&L and atomic rejection. Stock value participates in debt cover, bankruptcy estate and settlement net worth. Old ledgers without a `market` field remain decodable.
- SwiftUI adds a 2-second reducer-driven ticker during a human manage phase, symbol selector, live price/change/OHLC/volume/regime, Canvas line/area chart, share stepper, buy/sell buttons and portfolio rows. Dynamic values remain programmatic; no Astra or Kimi art was replaced.
- Local Swift 6.2.1/Linux evidence: `swift build --jobs 2` PASS; stock suite **11/11 PASS** including a 2,000-tick deterministic run; complete suite **121/121 PASS** including capped 500-seed AI smoke and 20 exploratory long games. ARM64 iOS `swiftc -frontend -parse` of the changed UI files PASS for grammar only.
- Three pre-existing branch test/build blockers were minimally repaired while validating: public member initializers for finance records, explicit Astra auction hit-zone names in its test, and removal of an AI reference to a nonexistent `freeHouseCredits` field. No gameplay replacement behavior was invented for that missing field.
- Exact design, bounds and verification commands: `Veilopoly/docs/OFFLINE_LIVE_STOCK_MARKET_20261107.md`. Xcode/iOS SDK type-check, simulator/device interaction, VoiceOver, keyboard, background behavior, frame time, host P5, main merge, workflow and IPA remain **UNVERIFIED / NOT PERFORMED**.

## Offline stock terminal UI/UE V2 — local verification (2026-11-06)

- Continuation task `VEILOPOLY-STOCK-MARKET-UI-002`, baseline `29db11b5b3679a879f589cf8eaa8dcfc3c210f3d`. Added a standalone SwiftUI trading terminal under the authorized `dev/veilopoly:VEILOPOLY_DEV/**` lane; latest Kimi K2 board, Astra interactive cards, lower-right operation entry and upper-right More/Exit separation remain unchanged.
- New terminal UX: five-symbol ticker strip and sparklines; price/volume Canvas chart with last-close reference; OHLC/volume/regime/halt hierarchy; buy/sell segmented ticket; exact estimated gross/fee/cash delta; 1/5/10/100/max shortcuts; explicit invalid-order reason; collapsible portfolio value, realized/unrealized P&L and per-symbol rows. Successful and rejected manual stock orders have separate iOS haptic feedback.
- Engine now exposes `StockTradeEstimate`, `estimateBuy`, `estimateSell` and exact `maximumBuyableShares`; reducer buy/sell uses the same estimate path as UI, preventing rounding drift. One new regression locks fee-aware maximum sizing and position capacity.
- Local Swift 6.2.1/Linux: `swift build --jobs 2` PASS; `StockMarketTests` **12/12 PASS**; full package **130/130 PASS**, including the newly merged Kimi resource/geometry tests, capped 500-seed AI smoke and 20 exploratory long games. ARM64 iOS frontend parse of UI, terminal, chart and feedback source PASS for grammar only.
- No new image/font/binary/third-party dependency was added. Xcode/iOS SDK type-check, actual 844×390 / 852×393 / iPad visual density, number-pad dismissal, VoiceOver order, haptic feel, Reduce Motion, GPU/frame time and physical touch remain **UNVERIFIED**.

