# Veilopoly 随机行情与自动账本 R1 — 开发分支验收说明

任务：`VL-VEILOPOLY-ECONOMY-RANDOMNESS-R1-20261107`
基线：`e8df1f0f05f1fcf1e2f0907d8c1e66301801e9fc`
授权：`dev/veilopoly` 下 `VEILOPOLY_DEV/**`，无 main 或 IPA 变更。

## 事实：已有能力（Codex）

- `StockMarketEngine` 已实现独立游戏 RNG、五家虚构公司、涨跌幅限制、均值回归、模拟冲击、成交量、停牌、现金结算和持仓。并非此前完全没有随机性。
- `GameFactory.make(seed:)` 已基于 seed 洗牌机会/命运卡并产生骰子序列。
- `IntegratedBanking.advanceTurn` 已根据已完成回合推进期数、产生到期通知；带规则表的投资结算使用种子驱动的骰子。收益表和利率有未经 Owner 核准的字段，不能自动虚构。

## 本轮实际修改

1. **开新局种子**：旧 UI 默认初始 seed=1729123，重开 seed+1，重复体验。现在不显式提供种子时使用 `SystemRandomNumberGenerator` 生成 UInt64；新局与终局再开也重新取样，不重复上一种子。**恢复存档不换种子**；开发测试依旧可传入明确的固定种子重放。随机性只在 iOS UI 新局边界引入，Engine/Network 仍然纯确定性。
2. **股票行情算法 V2**：不再固定在每第24个 tick 才改变 market regime，而是使用已保存市场 RNG 决定不规则切换时间和涨跌方向；每个标的拥有同 tick 的额外局部因子，偶发公共市场事件。原有 10% 区间限制、市场停牌、现金/订单、手续费、玩家持仓、历史长度全部保留。
3. **旧存档算法 V1 原样保留**：`StockMarketState.algorithmVersion` 使用可选 JSON 字段，历史记录缺失该键时解码成 V1，V1 编码省略此键，保留原有序列化及旧档已签校验结构；旧对局未来 Tick 仍消费旧 RNG 顺序。新开局通过 `StockMarketEngine.initial` 进入 V2。版本信息显示在股票终端下方。
4. **银行自动巡检**：使用真实 `completedTurns` 和现有账户存款、贷款、投资期数，自动列出已到期、两期内到期或收益条款未获批准的事项；超过5条收起摘要以保护 iPhone 7 布局。按当前 seed+期数轮换不涉及金额的柜台札记。**这不会自动放贷、自动收费、随机扣钱或承诺收益**。资金变化仍由现行引擎与玩家授权操作执行。
5. 不新增需要真钱下注、充值、提现、投注返奖的玩法。可以使用当前 `FinanceSandbox` 的无下注掷骰试验做纯随机教学，但它不是实际 GameState 的已批准可用功能。

## 现有测试源码（尚未 Xcode 执行）

- `StockMarketTests.swift` 新增 4 项：同种子 V2 重放、V1 JSON 无键兼容和旧 RNG、跨16种子的行情分歧、对骰子 RNG 的隔离；
- `VeilopolyNewGameSeedTests.swift` 新增 3 项：新局使用新 seed，32 次抽样多样性，显式固定种子可重放；
- `VeilopolyBankAutomationTests.swift` 新增 4 项：未开账本不造假、真实到期提醒、未核准收益回退、无状态副作用；
- 完整 SwiftPM/XCTest、Xcode iOS15 availability、iPhone7 真机、旧档 A/B 加载、跨设备同步**尚未执行**。主分支未动。

## 待审风险

- 旧存档若只保存了 Engine seed，市场 ledger 不存在：下一次首次启用市场使用新的 V2，这是合理的**首次开立**，不重写已有市场行情。
- UI 每2秒生成可记录的 `.stockTick` 操作，实际频率取决于活跃界面与 iOS 调度；仅变更价格走势的随机性，不擅自后台持续运行或虚构离线收益。
- 真实 P5 联机未实现；联机版本需让唯一权威主机决定 Tick 和 seed，再通过操作记录与认证消息同步，不能让多设备各自异步抽签。
- 原始桌游的银行利率、投资收益与所谓下注玩法尚无完整获批规则，故不会在本次以随机实现覆盖真实经济契约。

## 下一道门禁

用 Xcode iOS15 SDK 编译并跑完整 Engine/UI/Persistence XCTest；真实 iPhone7 iOS15.8.3 和 iPhone13 iOS26 做重开 20 次、市场 1000 tick、强杀恢复与交易股数准确性回归，然后由 Governor 审查是否进入 main。
