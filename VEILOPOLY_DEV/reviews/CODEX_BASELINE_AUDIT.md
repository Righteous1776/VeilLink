# CODEX-VEILOPOLY baseline audit

Task: VLP-CODEX-W0-001 / VEILOPOLY-CODEX-LONG-001 (#168). Date: 2026-11-07 UTC.
Branch: dev/veilopoly. Baseline main and development HEAD, fetched live:
`2c5b5161027edff097b27fe3323d30f6ca3e430e`.

## Authority and overlap

- Read current AGENTS.md, Inbox 00/01/authority/02/03, development GOVERNANCE,
  ROADMAP, CHECKPOINT, COLLABORATION, live #6/#168, game/model/render/decision,
  unified-rules/composition, finance/market, persistence/network and validation docs.
- Owner's current directive and #168 authorize only dev/veilopoly:VEILOPOLY_DEV/**.
  Main, host, Inbox, workflows, versions, signing, releases, IPA and P5 are excluded.
- #167 is an older, separate-branch grant. No changes to that branch or issue;
  this lane uses the newer #168 grant. Report overlap to #6, never overwrite work.
- Governance skill used for read-before-write, authority, evidence and checkpoint
  discipline. Its newer seal/read-set/learning-gate/session machinery is not
  installed in this repository: supplemental gate PARTIAL/UNAVAILABLE, not PASS.
  No governance files installed or changed. Existing explicit live-lane applies.
- #164 is CLOSED and UNMERGED, head 7f2c78b9abf38b45e6b59e89033bbf004a66730c.
  Its iOS CI 42355471423 succeeded for THAT head, not for future changes here.
  Six changed files: Engine Models/Rules, UI UI/BoardScene/StockMarketPanel,
  Engine StartAuctionTests. No wholesale restore, reopen, merge or cherry-pick.
  Selectively reimplement independently reviewed fixes; skipPurchase changes
  classic behavior and must not become the default. No dice-lab scope expansion.

## Actual composition and evidence

| Area | Existing source / reachable path | Status at baseline |
| --- | --- | --- |
| Engine | Models, Board, Rules: 40 cells, phases, reducer, integer money, seeded RNG, log/digest | VERIFIED portable regression; unresolved rule terms remain blocked |
| Finance | IntegratedBanking, StockMarket; manage drawer bank/market/trade | VERIFIED portable regression; fictional offline market only |
| AI | AI, FinancePolicyAdvisor; GameSessionModel driver | VERIFIED bounded legality, not reliable full-game completion |
| Persistence | GameSaveStore; GameSessionModel synchronous action checkpoints and A/B restore | VERIFIED portable corruption/round-trip checks; power-loss/flash/latency UNVERIFIED |
| Network | Net, MultiplayerResumeHandshake | VERIFIED protocol mocks; VeilLinkTransportAdapter intentionally not integrated, P5 BLOCKED |
| Rendering | BoardScene, KimiK2BoardSkin, RenderCommands, ACK gate | Portable projections/resources VERIFIED; SwiftUI/SpriteKit behavior SOURCE-ONLY locally |
| Controls | UI.swift root, operation drawer, tile inspector, stock terminal | SOURCE-ONLY; known reachability/keyboard/theme defects below |
| Content/assets | Bundled content, Kimi/Astra aliases, resource audits | Portable integrity tests VERIFIED; actual device texture budget UNVERIFIED |

The current main already contains the hall entry and V28 integration. That does
not grant this lane authority to change the hall or enable real multiplayer.
Earlier docs' 31/134/139 tests and absent-iOS-build claims are historical, not a
current inventory. Baseline main also has historical Apple CI evidence; this
audit does not convert it into new-head iOS or physical-device acceptance.

### Executed baseline

`PATH=/workspace/scratch/swift-6.2.1/usr/bin:$PATH swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2`
→ Linux Swift 6.2.1, 237 XCTest cases, 0 failures, 36.443s test time → PASS.
Build completed in 0.91s (incremental). AI 500 seeds × 500-move cap:
0/500 naturally complete, 500 capped, zero illegal moves; test time 16.656s.
LongSim output and full-game evidence must be reported separately; neither
bounded result is a claim of 500 complete games. No AI algorithm changed in W0.

`gh api .../pulls/164` → closed, merged=false, exact head above → PASS (read-only).
`gh api .../actions/runs/42355471423` → success at #164 head → PASS (historical only).
New Apple SDK compile/XCTest, simulator, iPhone touch/keyboard/ACK, FPS/thermal,
power-loss and two-phone tests → unavailable in Linux environment → NOT_RUN.

## Prioritized executable queue

| ID / priority | Reproduce / expected | Exact source anchor and finding | Evidence / next gate |
| --- | --- | --- | --- |
| W1-001 / P0 | Roll, watch any token traverse board; framing must stay fixed throughout movement, completion and skip | BoardScene.play tokenMove runs camera scale 0.83, then unkeyed restore 1; fastForward cancels only keyed focus action | CONFIRMED SOURCE defect; independently remove movement camera actions, add iOS scene/ACK regression |
| W1-002 / P0 | In buy/auction/debt/animation, inspect own property, bank, market, trade without changing phase or cash | UI.operationDrawer only exposes managementNavigation in manage; actionPanel selects decision instead of independent browsing | CONFIRMED SOURCE reachability gap; add phase-independent read-only projections, never bypass reducer permissions |
| W1-003 / P0 | Enter bank, auction, trade or stock amount on iPhone landscape; all confirm/cancel controls remain accessible | UI numberPad fields; no unified bounded input/keyboard dismissal; #164 custom keypad is reference only | SOURCE-ONLY layout risk; validate actual iPhone keyboard and scroll before acceptance |
| W1-004 / P1 | Toggle day/night, open forms and market; all layers remain coherent and readable | UI root preferredColorScheme(.dark), numerous fixed white colors; board can switch ivory | CONFIRMED SOURCE mismatch; audit palette before changing globally |
| W1-005 / P1 | Tap all controls/40 cells, drag financial windows near safe edges, rotate, restore | LandscapePresentation/LayoutMetrics, UI overlay hit areas, BoardScene touchesEnded | UNVERIFIED physical hit regions, drag arbitration and safe-area clamping; no generic assertion of 44pt correctness |
| W6-001 / P1 | Kill after dice/purchase/payment, restore exact seq/hash without duplicate action | GameSaveStore and UI checkpoint/command lifecycle | Portable tests PASS; device hard-kill/low-storage and main-thread latency NOT_RUN |
| W3-001 / P1 | Paired seeded old/new AI tournaments | AutoplayTests/LongSimTests, AI.nextMove | 0/500 bounded completions; add full completion/cap/illegal/runtime baseline before policy changes |
| W2/W4 | Expand invariant/replay/finance adversarial tests | Rules, IntegratedBanking, StockMarket | Existing portable tests PASS; no invented approved yields/rates/winner rules |
| W8 | Host seq/hash/duplicate/reorder/resync simulations | VeilopolyNet | Local mocks allowed; actual P5 integration BLOCKED pending new authority |

Rules awaiting Owner remain in SPEC_DECISIONS_REQUIRED and finance docs: yields,
4+ collateral, GO/building conflicts, stars, liquidation priority and other
unapproved terms. Preserve current behavior. Do not silently activate #164's
skipPurchase or introduce real money, wagering or exchangeable rewards.

## Handoff

Current stage: W0 audited; first commit contains this review only, as #168 asks.
Cross-Agent conflict: no overlapping local changes; #167 task overlap registered
for coordination, no shared-branch ownership assumed. Assets unchanged.
NEXT_ONE_TASK: VLP-CODEX-W1-001 — stable movement camera and one-shot ACK regression.
Current state: READY_FOR_W1. No merge, release or workflow dispatch authorized.
