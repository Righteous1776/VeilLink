# Veilopoly Development Checkpoint — 2026-11-06

## MANUAL-CN-V1 — 完整玩家说明书（2026-11-08）

- 说明书独立分支 dev/veilopoly-manual-v5-20261108，基线 0ef5b71；不覆盖其他 Agent 的研发任务。
- 由统一 editorial 主稿生成：13 章、162 条条目、40 格地块、32 张 V5 卡牌、可搜索 Swift Engine 只读数据及 54 页 A4 中文 PDF。
- 新增 VeilopolyCompleteManual.swift 与 VeilopolyCompleteManualView.swift；现有 VeilopolyGuideSheet.swift 保留 23 条简明词条，加入「完整规则说明书」NavigationLink。
- 完整 Markdown 主稿与 JSON 章节数据入库，任何后续逐字修改必须同步更新 Swift 与 PDF；版本为 VEILOPOLY-MANUAL-CN-V1-20261108。
- 披露：当前 V5 Apple SDK、完整 SwiftPM、iOS 真机、多设备联机以及 100 种子压力测试均未获得本分支有效通过回执。说明书不能当作发布证明。
- 不改变 Engine 资金规则、GameState、身份、Wire、SQLite、主干或构建工作流。没有打包 IPA 或合并 main。


## MACRO-FINAL · ECON V5 consolidated review — 2026-11-08

- Governance: Owner requests final macro iteration. Isolated branch `dev/veilopoly-risk-review-v5-20261108`; base from `dev/veilopoly-economy-v5-20261107`, not main or live dev. All code under `VEILOPOLY_DEV/**`.
- Mapped monetary base, protected bank reserves, liabilities/IOUs, loan underwriting, property/house inventory, event payouts, peer transfers and stock exposure. P0 V5 estate changed to noncash transfer/writeoff; V4 kept unchanged.
- Revised interest/maturity receipt text, liquidity no-liability display, crisis exposure reporting, FIFO priority and forced liquidation. Estate tests authored, **not executed**.
- Formal review: `VEILOPOLY_DEV/reviews/MACRO_FINAL_20261108.md`.
- New current-head 100-seed stress test **source committed, execution NOT_RUN**; reports natural finished vs capped games, bank IOU peaks, first bankruptcy and crisis ticks. **Next one gate**: reproduce current branch with Swift 6.2.1, full `swift test`, execute stress tests and fix failed cases, then Owner/Governor review of branch conflicts. No build IPA, signing, release or merging.
- Do NOT claim complete crisis robustness, Apple SDK pass, iOS playability or measured game duration.


## ECON-V5-CRISIS-001 — Systemic risk controls / banking IOUs — 2026-11-08

- Isolated risk review branch dev/veilopoly-risk-review-v5-20261108, independent of concurrent Veilopoly writers. Owner and Governor scoped VEILOPOLY_DEV only.
- Finance risk diagnostic, conditional lending buffer, credit book limit, stock-stress response, partial V5 settlement of matured deposit/investment/stock positions, FIFO outstanding bank claims, player claim UI.
- V5 money supply remains fixed at 2,100,000, no bailout minting. V4 frozen terms/saves not migrated. New regression test sources and audit in reviews/ECON_V5_SYSTEMIC_RISK_AUDIT_20261108.md.
- RISK-005/006: automatic debt coverage now skips unavailable savings/stock cash and can reach the debt phase without breaking monetary conservation; credit stops when contingent claims exceed treasury. Bankruptcy-estate redistribution and comprehensive lender priorities STILL OPEN/P0; do not label crisis handling complete.
- Exact-head full SwiftPM / Apple SDK / phones NOT_RUN. Next task: tests, then forced-liquidation rescue and 100-seed stress. No merge, workflow, packaging or IPA.

## ECON-V5-LIQUIDITY-001 — 新单机资金扩容（独立分支，未集成）— 2026-11-07

- 因 dev/veilopoly 被并行写入而建立 `dev/veilopoly-economy-v5-20261107`，基于其 HEAD `542f637`；保证不覆盖其他 Agent 的货币清算/待兑付队列改动。
- 新局 V5 城市银行储备 ¥2,000,000，玩家4×¥25,000，总发行游戏币 ¥2,100,000，严格执行 V5 独立资金守恒；V4 旧 ¥188,800 上限、原行情/贷款/卡牌/存档不重估。
- 地产购买/建筑×12，租金×8，起点¥3,200，早期租金保护¥3,200→后期¥24,000，贷款额度¥6k/12k/24k/40k且只按合同计息，股票报价×24，机会/命运现金与修理面额×4并同步文案。玩家可用现金、银行储备和总量分开显示。
- 旧 V4 无 queuedClaims 键的已封存存档仍可被接受，下一次实际银行兑付时才生成列表；并行 Agent 的待兑付逻辑、原 Cash Move 和 Wire schema 保留。
- 新增 V5 engine 测试代码并将旧 V4 测试固定到 makeV4。**当前 HEAD SwiftPM/XCTest、Apple SDK、真机、双机全部 NOT_RUN**，仍需整局经济 A/B 数据校准。
- 完整评审：`VEILOPOLY_DEV/reviews/ECON_V5_MONEY_CIRCULATION_20261107.md`。下一任务：校验 exact HEAD SwiftPM + V4/V5 同 seed 对照；不得打包、合并、IPA。


## ECON-007～013 — 统一银行流动性 / 玩家直转 / 免费房屋 / 联动市场 V4 — 2026-11-07

- Owner明确新需求：机会/命运大事件送一栋免费房屋；交易可直接指定收款玩家；银行资金总量固定、贷款/地产/股票/卡牌共用商业环境。
- 新单机V4：玩家现金4×7200，初始银行160000，总货币供应固定188800；每笔授权状态变更前后用玩家现金总变化原子清算银行资金，存档写入与加载校验守恒。银行流动不足返回 bankLiquidity 并保持状态未提交；旧V3/经典存档没有reserveCash字段，原样兼容。
- V4 机会13、命运27两张牌是真实免付费建房且消耗银行实体房屋，保持建造均衡/地产归属/抵押校验；无合法位置固定领取800/600；旧卡池不变。
- V4 支持单机直接转账给指定非破产玩家，不需对方接受；完整地产/现金交换依旧走需响应的交易合同；P5真实双机目前仍沿用经典协议。
- 股票 Tick 根据全市可流动现金、建筑投资与财富分布产生可复现宏观反馈；银行/股票/资产资料显示总货币量和信号；旧市场版本不受新压力参数影响。
- 新增现金守恒、转账、房屋赠与、银行不足回滚、股市资金流、存档污染验证测试代码；**完整SwiftPM、Apple SDK、iOS设备和长局测试 NOT_RUN**。
- **阻塞项**：极长期低银行余额下强制发薪/卡牌支付可能不可结算而卡住回合；需制定不增发货币的可执行破产/兑付机制后再宣称成熟。下一唯一任务是精准HEAD编译全测→修复后做有限银行长局压力测试；禁止合并/打包/IPA。


## BAL-001–004 — 机遇／机会／命运与全局经济平衡（测试待跑）— 2026-11-07

- 新版仅在**新开单机 V3**：32 张原创机会/命运卡（各16）；「机遇」为机会卡主题分类而非第三 DeckKind，避免改保存/Wire。所有卡牌文案与实际金额一致，纠正了 V3 对原样本金额暗乘3却显示老数额的问题。
- 机会直付银行事件单轮净流入+1000；命运+2210（不包括起点、玩家间转移、租金、修缮）。单次现金罚款≤500；出狱卡各类仅限持一张、重复折现250；完整卡池抽毕隔离骰子 RNG 确定性重洗牌。
- 长局前期租金上限900，每完成一个普通玩家回合递增80，最高6500；铁路/公共事业基础租金按新地价×3适配；资产资料显示本期上限。AI V3 安全现金底线1200～2400，避免早期无现金而又不阻断后期购买。旧对局规则全部不动。
- 实际 Engine/AI 测试源码新增：卡牌目录金额、两种牌堆现金和、玩家间转移守恒、重复出狱卡、确定性重洗、早/晚真实租金裁决、AI现金保护、旧存档。
- Github 卡定义静态检查 32 ID/16+16/正负分布 PASS；**当前HEAD SwiftPM 全量/Apple SDK/真机/双机 NOT_RUN**，不宣称已经达到目标时长。下一唯一任务：SwiftPM全量测试＋同种子A/B完局率/破产时序评估，收集真实手机对局时长，闭环调优。
- 评审：`VEILOPOLY_DEV/reviews/BAL_V3_EVENTS_20261107.md`。未合并、不打包、不发布 IPA。


## ECON-001–006 — 城市长局经济重构（研发中）— 2026-11-07

- Owner实测反馈：约20分钟结束、频繁破产、收入与支出规模偏小、银行和模拟股票缺乏策略深度。只能作为一次体验反馈，尚无群体统计。
- v3 仅供**新开单机局**，旧单机存档自动加载并保留经典参数；P5 双机大厅仍为经典配置，后续需版本化房间协商后才可让双机用 v3。主 Gameplay/save schema 未增字段，v3 以 bank.financeRuleVersion=3 / stock.algorithmVersion=3 显式持久化。
- 初始现金7200，经过起点1100，买地/建造3倍，租金2倍，税费/卡牌现金/修理费用约3倍，入狱保释150；AI预留现金增加，减少早期资金紧缩。
- 贷款8%–17%按合同一次计息（旧的20%–45%逐期公式仅留给经典局）；扩大额度并允许4+地产；活期锁1个结算期后1.5%，定存4期8.5%，启用3种有盈亏区间的离线投资产品；股市v3报价基准8倍、振幅增加、单笔费率0.25%（最低1游戏币）。
- bank UI 新增贷款报价、定存、管理/创投/虚拟指数；stock UI 标注v3，旧行情/存档兼容逻辑保留。数据不会变现。
- 对照入口 LocalGameRunner.compareEconomy 在两种配置下跑同种子，报告完整完局数、首次破产序号、真实完成回合、现金与地产分布，不把 cap 当作完局，也不把 move 数当作真实分钟。
- 新增 CityLongEconomyTests / CityLongAutoplayTests 源码。**没有**在当前 HEAD 运行完整 SwiftPM XCTest、Apple SDK、模拟器、真机或双机测试。Codex旧版271项通过不能用于本版验收。
- 源码变更仅 dev/veilopoly:VEILOPOLY_DEV/**；main、VeilLink底层通信、身份、数据库、workflows、version、签名、IPA未变动。
- 下一唯一任务：在可用完整仓库的Swift6.2.1 runner完成精准HEAD测试与12组seed对照；修不通过的逻辑；校准破产率、节奏和收益分布。Apple设备/P5房间协商必须另行验收，不打包不合并。


## GPT CONTINUATION-004 — checkpointed W2 save validation — 2026-11-07

- Current preceding source commits: P5 foreground propagation 09ac83b; W5 journal 2a0975e; W2 reducer preflight 6d51426; W2 persistence preflight 109fb10.
- W2-003: two-slot save now rejects out-of-range auction, trade and debt participant references, transferred tile references and malformed counters/deck cursors before replacing a verified slot. Test source covers 7 bad states and retention of the last good slot.
- W5: 16 read-only achievements were added through a separate native journal, derived from Move log/current holdings; no rules or currency rewards. Local structural Swift smoke PASS; no full-package or iOS proof.
- Device/platform: Apple SDK/XCTest, simulator, two-phone BLE/LAN and actual iOS full-screen lifecycle are NOT_RUN. Existing 271/271 Linux baseline is prior-head evidence ONLY, not current HEAD.
- Scopes: all product changes confined to dev/veilopoly with the prior Owner-approved hall/host exception; main, signing, workflows, version, packaging and IPA unchanged.
- Next task: exact-head full SwiftPM regression (without release), then Apple SDK typecheck/XCTest and two-phone lifecycle/large snapshot validation. Continue additional gameplay content only without destabilizing these gates.


## GPT CONTINUATION-003 — Pure Engine malformed state guards — 2026-11-07

- Base 2a0975e. Guard invalid trade/auction/debt participant references, negative deck cursors and overflow counters before indexing or mutation. Four regression tests added; full SwiftPM and Apple SDK NOT_RUN; no rules or persistence format change.
- Evidence: reviews/GPT_CONTINUATION_003_PHASE_GUARDS.md. NEXT_ONE_TASK: actual full package regression and snapshot stress. No build dispatch, main merge or IPA.


## GPT CONTINUATION-002 — Read-only achievements — 2026-11-07

- Prior live head `09ac83b`. Added 16 original no-stakes achievement milestones and phase-independent journal in asset browser. Historical counters derive only from recorded committed moves; portfolio objectives deliberately reflect current holdings. No added persistent schema, rewards, gameplay move, market effect, RNG or wire format.
- New four-case Engine unit suite plus iOS journal UI; isolated Swift 6.2.1 smoke PASS against minimal matching interfaces; full SwiftPM package, Apple SDK, iOS XCTest, simulator and devices NOT_RUN.
- Review: `reviews/GPT_CONTINUATION_002_ACHIEVEMENTS.md`. No main merge, packaging, workflow, version, release or IPA.
- NEXT_ONE_TASK: bounded snapshot/phase reference hardening and validation; verify platform gates when possible.


## CODEX P5-001 — Owner-authorized live integration — 2026-11-07

- Owner explicitly expanded scope to Veilopoly + hall/host bridge/tests on dev,
  overriding prior P5 exclusion ONLY. Receipt `reviews/P5_OWNER_SCOPE_20261107.md`,
  #6 issuecomment-6707080274. No transport/Wire/security/identity/DB/main/release
  edits. main still `2c5b5161027edff097b27fe3323d30f6ca3e430e`, before dev `bcf683f`.
- Foundation `5c2ecda`, budget/recovery `d34cb74`, history guard `61245ef`,
  iOS model `f8a6722`; host hookup follows
  in this checkpoint's commit. Real route: hall -> live model -> authenticated
  control-event bridge -> existing SessionCoordinator API, no plain-chat payloads.
- First topology explicitly TWO phones / two humans + two existing AI, not
  four-phone support. Explicit invitation, host-only reducer/AI/price clock,
  guest proposals, sequence/hash/history-prefix checks, heartbeat/resync,
  role/identity-separated saved room recovery and bounded fragment transport.
- Full Linux suite 271/271 PASS, 58.527s. Live suites 16 cases PASS. Actual
  unchanged control-event codec probe: 31 fragments all <=2048 bytes. Initial
  512-byte worst-case probe failed; corrected to 384 raw bytes, not a cap change.
- Host hookup `eb88167`; follow-up stops game timeout from reseeding shared
  secure sessions. Only explicit user recovery of a MISSING secure session
  calls the existing recovery API; automatic game monitoring only pauses/resyncs.
- iOS15 grammar parse PASS ONLY. Apple SDK/type-check, 8 guarded iOS model
  cases, 2 host XCTest cases, simulator, two phones, actual link/lifecycle/FPS/
  battery are NOT_RUN. Historical strict Codable warnings still unresolved.
- Read `reviews/P5_LIVE_INTEGRATION_20261107.md` for actual route, limits,
  failure handling and non-IPA acceptance steps. This is SOURCE_INTEGRATED,
  PORTABLE_VALIDATED, not physical LINK_VERIFIED or main MERGED/RELEASED.
- NEXT_ONE_TASK: VLP-CODEX-P5-002, Apple SDK + two-phone acceptance WITHOUT IPA.
  No hidden background Codex worker; resume from current Git HEAD/#6/#168.

## CODEX W2-001 — purchase/auction reference crash — 2026-11-07

- Before `72521c9` (touch fix); theme slice `06a659a`. Same #168 dev-only
  authority; main remains `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
- Reproduced baseline malformed purchase crash: exit 1, array index failure,
  signal 4. Separate baseline auction/save tests: 3 cases, 18 assertion failures.
- Added bounds checks before buy/startAuction/existing auction settlement;
  storage rejects invalid pending/auction deed refs and falls back to older
  valid slots. No rule/price/RNG/serialization/schema/resource/host changes.
- Targeted Engine + save + existing buy/auction/bid suite 20/20 PASS. Full
  Linux Swift 6.2.1 suite 255/255 PASS, 30.365s, including old sealed saves.
  Apple SDK / iOS XCTest / simulator / real device / hard power loss NOT_RUN.
- Same fixed AI corpora before (W1-005) vs after: 500×500 cap 0/500 complete,
  500 capped, zero illegal actions in both; 20×6000 cap 9 complete/11 capped,
  79,661 moves in both. Smoke runtime 21.837s → 13.428s; long runtime
  13.661s → 12.451s. Uncontrolled Linux timings, NOT a speed/strength claim;
  per-seed old/new final-hash differential benchmark NOT_RUN. AI policy unchanged.
- See `reviews/W2_001_DEED_REFERENCE_SAFETY.md`; semantic validation is not a
  complete malformed-state or security audit. FNV remains non-authenticating.
  Historical strict Codable warnings unresolved; strict build not rerun here.
- NEXT_ONE_TASK: VLP-CODEX-W2-002, remaining auction/trade/debt participant and
  phase-payload bounds. W1 Apple acceptance and safe HUD dragging remain open.
- State: scoped portable-verified fix, ready for Governor review; no main merge,
  P5, release, IPA or workflow dispatch. Refresh HEAD/#6/#168 before continuation.

## CODEX W1-005 — touch-region minima — 2026-11-07

- Before `06a659a` (theme fix), same #168 dev-only grant; main unchanged.
- Animation skip, stock portfolio toggle/rows now explicitly contain minimum
  44pt targets; narrow quantity shortcuts wrap with adaptive columns. No
  overlapping invisible targets, new gestures, assets or rule changes.
- Targeted layout/ACK/stock tests 21/21 PASS; full Linux suite 249/249 PASS,
  42.572s. iOS15 grammar parse PASS only; Apple SDK/rendered touch/VO NOT_RUN.
- See `reviews/W1_005_CONTROL_HIT_AREAS.md`. Full safe-area dragging remains
  unfinished; source declarations are not physical hit-test acceptance.
- NEXT_ONE_TASK: VLP-CODEX-W2-001, reproduce and reject out-of-range
  pendingPurchase references before purchase/auction or checkpoint persistence.
  Potential crash takes priority over additional theme/drag polishing.

## CODEX W1-004 — interface theme consistency — 2026-11-07

- Before `8865668`; main still `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
  Same Owner/#168 dev-only lane. See `reviews/W1_004_INTERFACE_THEME.md`.
- Existing day/night preference now drives canvas, native dialogs, numeric
  sheets, reference book and news. Explicit dark Astra/stock islands preserve
  text contrast over signed artwork. No resource/rule/save/host changes.
- Theme tests 4/4 PASS; full Linux suite 248/248 PASS, 38.559s; iOS15 grammar
  parse PASS only. Apple SDK/device/modal propagation/screenshots NOT_RUN.
- Strict warnings gate remains a known historical FAIL, not waived. Newer
  governance skill machinery absent; supplemental gate PARTIAL, no fabricated PASS.
- NEXT_ONE_TASK: VLP-CODEX-W1-005, animation-skip and stock portfolio touch areas.

## CODEX W1-003 — keyboard-safe numeric drafts — 2026-11-07

- Task authority: #168 + current Owner; `dev/veilopoly:VEILOPOLY_DEV/**` only.
  Main baseline still `2c5b5161027edff097b27fe3323d30f6ca3e430e` (live recheck).
  Prior checkpoints: W0 `f3a7b12`, W1-001 `de8893f`, W1-002 `4f1b255`.
- Replaced eight bank/auction/trade/stock numeric TextFields with a shared
  bounded draft keypad sheet. Cancel does not write, Confirm only fills input;
  existing reducer still authorizes and executes actual actions. No rule,
  financial term, save format, resource, host or protocol change.
- `swift build --package-path VEILOPOLY_DEV/Veilopoly --jobs 2` → success in
  14.52s → PASS, with six pre-existing immutable Codable property warnings.
- `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2` → 244 tests,
  0 failures, 32.310s → PASS. Numeric draft cases 4/4 PASS; asset projection
  cases 3/3 PASS. New guarded camera cases are NOT_RUN on Linux, not counted.
- iOS15 frontend grammar parse → exit 0 → PASS (syntax only). Apple SDK/iOS
  XCTest/simulator/physical keyboard/touch/layout/VoiceOver/ACK → NOT_RUN.
- Supplemental warnings-as-errors build → FAIL on unchanged historical
  FinanceExpansion.swift:11–16. Recorded separately; no suppression, mutable
  reference rules or fake strict PASS. See `reviews/W1_003_NUMERIC_INPUT.md`.
- Cross-Agent conflicts: none in local worktree; #167 branch and closed #164
  untouched. No main merge, workflow dispatch, signing, release or IPA.
- NEXT_ONE_TASK: VLP-CODEX-W1-004 — theme consistency audit and scoped palette
  fix; preserve Astra/Kimi art contracts and avoid black text on dark skins.
- State: W0 complete; three W1 source slices implemented with portable tests;
  W1 Apple/device acceptance remains open. Resume by fetching current HEAD,
  reading latest #6/#168 and this topmost checkpoint. No background worker claim.

## CODEX W1-002 — independent asset browser — 2026-11-07

- Baseline `de8893f`, same #168 dev-only authority. Added read-only native asset
  sheet reachable through More and drawer in every phase, including pending
  decisions. Property/bank/stock/trade data use existing canonical state; no
  order callbacks, rule changes, finance initialization or art replacement.
- `AssetBrowserSnapshotTests` → 3/3 PASS; full Linux Swift 6.2.1 suite →
  240/240 PASS, 39.571s. iOS15 grammar parse PASS only. Apple SDK, iOS UI tests,
  device keyboard/touch/chart/scroll/ACK acceptance NOT_RUN.
- See `reviews/W1_002_ASSET_BROWSER.md`; W1-001 is `de8893f`, W0 `f3a7b12`.
- NEXT_ONE_TASK: VLP-CODEX-W1-003, keyboard-safe bounded numeric input;
  existing reducer remains authoritative for legal amounts and trading phases.

## CODEX long-line W0 + W1-001 — 2026-11-07

- Authority: current Owner + #168 `VEILOPOLY-CODEX-LONG-001`; only
  `dev/veilopoly:VEILOPOLY_DEV/**`. Old hall/release permissions below are
  historical, not permission for this task. No main/P5/IPA/workflow changes.
- Live baseline main/development: `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
  W0 review-only commit `f3a7b12`; see `reviews/CODEX_BASELINE_AUDIT.md`.
- W1-001: remove token-movement camera zoom and delayed restore; preserve token
  timing, assets, reducer, RNG, save encoding and one-shot ACK. Guarded iOS scene
  regression source added; details in `reviews/W1_001_STABLE_CAMERA.md`.
- Linux Swift 6.2.1 full `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2`
  → 237 tests, 0 failures, 32.033s → PASS. New guarded iOS cases are excluded on
  Linux, NOT_RUN; iOS15 frontend grammar parse exit 0 → PASS (syntax only).
- Baseline AI: 0/500 complete at 500 moves (500 capped); 9/20 complete at 6000
  moves (11 capped), 79,661 moves, zero illegal actions. No policy change or
  strength claim. Device/Apple SDK/visual/performance/real multiplayer NOT_RUN.
- #164 remains closed/unmerged. #167 is a different branch/task; do not modify.
  No local cross-Agent conflict found; no art replacement or rule expansion.
- NEXT_ONE_TASK: VLP-CODEX-W1-002, independent read-only asset browser in all
  phases; mutation controls stay bound to existing legal reducer phases.

## Actual game-hall integration + quiet live news — 2026-11-07

- Task `VEILOPOLY-HALL-NEWS-008`, baseline `ac1805a3f8dcf4c1a657ecfff0f64650f037b736`; main/merge base `ccafebab147e069fbabfff579dbf323b0d54f191`. Owner now explicitly requests actual hall integration and notifications, but **no new version output**. Earlier notes that P5 hall integration is unauthorized are historical for this narrow local-hosting task; product multiplayer transport is still excluded.
- `project.yml` links local `VeilopolyUI`; `GameLobbyView` opens the actual offline game fullscreen. Existing save/resume, unified finance, stock, AI, ivory/Astra/Kimi art and editorial remain intact. Nil presentation seed now allows new-match entropy while retaining saved/explicit seeds.
- Live ticker: 86 local copy entries; committed real financial/event/market notices plus nonfinancial city vignettes, bounded priority queue 6, 60-second topic cooldown, 14-second display / 8-second gap, ambient eligibility 45 seconds. Board/More/Exit separation, pause menu, Reduce Motion, background pause and full-sentence accessibility are implemented. Gameplay state/RNG are not changed by news.
- Offline bundle test resolves **99 PNG + 13 WAV + 1 XML**; compiled content tests cover **32 cards / 40 streets / 5 issuers / 23 guide topics / 86 news entries**. This is real local module-bundle evidence, not phone installation.
- Final Linux Swift 6.2.1 `swift test --jobs 2` → **237/237 PASS, 0 failures**, including 8 bulletin and 2 bundle tests. ARM64 iOS15 frontend syntax parse, YAML host/package/version checks, existing landscape Info.plist declarations and diff checks PASS. Apple SDK type-check/link, orientation, graphics/touch/audio and actual device installation remain **PENDING**.
- Version 27.2/build64, workflows, release/signing, keys, database, transport and other games unchanged. No PR/main merge: existing PR CI packages an IPA, and main `project.yml` changes trigger automatic release. No new package/version/workflow dispatch. Source delivery stays on `dev/veilopoly`.
- Detailed acceptance and continuation: `Veilopoly/docs/HALL_NEWS_INTEGRATION_20261107.md`. Next: authorized Apple host compile/test without packaging, then visual/lifecycle/save/exit acceptance; IPA-producing paths wait for Owner's renewed version-output request.

## Generated tile art and legibility pass — 2026-11-07

- Task `VEILOPOLY-TILE-ART-007`, baseline `56f3790fc3fcf107da6925f25843a42ce14d3f94`. Owner requested further generated local images to improve rough jail/utility/property areas. The later classic-board reference was withdrawn; no complete reference-board effect image is installed.
- Generated ten independent special-space symbols plus a blank ivory/brass tile face. Eleven runtime RGBA PNGs total 270,553 bytes / ~1 MiB decoded; two originals and per-file hashes/crops/provenance retained in `INCOMING_ASSETS/ASTRA_TILE_ART_R1`. All-or-nothing activation preserves original Kimi atlas/masks if any new file fails loading.
- Actual GameState determines symbols and property colors. New faces have no preview labels to mask. Full live names orient toward the screen, streets allow two lines, price and owner zones are separated; building sprites use one reserved row, bands occupy the inner edge. Two static central card stacks reuse generated face/icon assets without changing deck rules or adding draw actions.
- Local Linux Swift 6.2.1: build PASS, new art/layout tests 3/3 PASS, full suite 159/159 PASS (0 failures), manifest SHA-256 11/11 PASS, ARM64 iOS16 grammar/shell/diff checks PASS. New Apple-only live-label/fallback checks are source-only and unexecuted. Layout samples were inspected as image composites, not iOS screenshots; Apple text layout/touch/visual scale remains PENDING.
- Review and repeatable preview: `Veilopoly/docs/TILE_ART_AND_LEGIBILITY_20261107.md`, `tools/preview_refined_tiles.sh`. No Engine/Net/Persistence/main/P5/workflow/version/release changes.

## Generated detail sprites — 2026-11-07

- Task `VEILOPOLY-DETAIL-ART-006`, baseline `d06afc81351725c198b2625ba76b63306e80d982`. Owner directed using generated small images for refined visual composition. Generated one transparent 3×2 sprite sheet with blue pawn, red car, green ship, gold airplane, green-roof house and red-roof hotel; source/provenance/hash/crops retained under `INCOMING_ASSETS/ASTRA_DETAIL_SPRITES_R1`.
- Six runtime sprites at 128×128, total 119,511 bytes; ~384 KiB decoded estimate. Actual generated artwork is mechanically cropped/trimmed/resized, with transparent padding. Board and HUD share the same generated→Kimi→Kenney token fallback order; the building pair falls back atomically. Original art files remain unchanged.
- Detailed buildings counter-rotate their parent tile to preserve one camera/light direction on all four board edges; sizes, state-driven counts, player formation and animation ACK remain unchanged. Alpha-aware light-background sheet and true-size 34/14/21px samples inspected as image composites, not device screenshots.
- Local Swift 6.2.1/Linux: full XCTest 156/156 PASS, art/resource/formation selection 8/8 PASS; manifest SHA-256 6/6 PASS; iOS16 ARM64 frontend parse and shell/diff checks PASS. Apple SDK type-check and actual touch/render/GPU acceptance PENDING. See `Veilopoly/docs/DETAIL_SPRITE_COMPOSITION_20261107.md`.

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

