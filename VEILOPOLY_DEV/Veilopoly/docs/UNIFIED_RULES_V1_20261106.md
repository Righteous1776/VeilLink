# Veilopoly · 单规则集整合 V1（Owner 2026-11-06）

## 决策

Owner 明确要求**一套游戏规则**，不做经典与银行两个入口。统一架构：`GameState` 单一权威状态 + `Move` 单一 seq + `seededRNG` 单一随机序列 + `Effect` 单一事件流 + `StateDigest` 单一状态哈希。`FinanceSandbox` 保留为历史验算/实验工具，不再作为对局权威端；新的 `IntegratedBanking` 和 `FinancialRuleJudge` 直接与 `VeilopolyEngine.apply` 协作。

## 本批实际实现

- 正式 `MoveKind`: `bankDeposit`、`bankWithdraw`、`bankBorrow`、`bankRepay`、`bankInvest`、`bankSettle`；操作只在资产管理 phase 允许。金融参数 `Move.financeProduct/financePeriods/financeID` 随主 `Move` 编码和记录。
- 游戏内玩家唯一资金源：`GameState.players[].cash`。`GameState.banking` 只记录未结算存款、借据、模拟投资和期限，**不存第二份现金**。`GameState` 里可选金融字段保证旧快照缺键仍可解码；首次金融操作初始化。
- 手写的借款四档：20%、30%、40%、45%；0–3 块未抵押资产的上限依次 ¥500/1000/4000/7000；四块及以上不擅自套用三块额度，返回 `FinanceTermsPending`。贷款额/借期/次序统一通过 `FinanceSandbox.loanQuote` 计算（简易利息，整数）。
- 活期可存取，未判明收益时保持**0% 保本临时规则**，绝不宣称这就是手写利率；定期存款及股票/风险投资/理财在审批收益表前会返回 `FinanceTermsPending`。若规则方批准 `FinanceSandboxPolicy`，使用 `IntegratedBanking.configured` 先写入 GameState 后才能参与哈希与正式对局。
- 结算期限由引擎内纯计数 `completedTurns` 驱动，**普通完整玩家回合**完成一次算一个期间，掷出双骰的追加行动不算；不使用 `Date` 或真实时间。
- 到期只发 `bankMatured` 提醒，不自动扣费；提前还清贷款可行但仍按约定总额结清。抵押物冻结、贷款违约的准确执行及债权优先级尚需规则方确认。
- 游戏失败时，存款**本金**先归入破产清算遗产，再进入原有的地产/现金流转链；未结算模拟仓位不自动生成虚构收益。金融权益归属和贷款优先级要继续验收。
- 新 `EffectKind` 独立标记：`bankDeposited`、`bankWithdrawn`、`bankBorrowed`、`bankRepaid`、`bankInvestmentOpened`、`bankInvestmentSettled`、`bankMatured`。仅输出语义事件和合法的金融数值，由 Kimi 补充游戏动画规范/素材。
- `FinancialRuleJudge` 纯函数评估到期债务、存款和投资；AI 直接用它处理到期资产，不使用神经网络权重或不可复现实验。

## 稳定性和“规则模型训练”的真实范围

目前**不是声称已经训练出机器学习权重**。实际完成的是确定性规则裁决器 + 回归样本/多种子自对弈的行为验证框架：拒绝错误 phase/seq、失败不改变 stateHash，旧存档兼容，包含股票收益表时规范化编码保证多次重放逐位一致。针对金融开放、到期、破产等验证。后续可在不改变确定性前提下对 AI 决策策略进行离线多种子评估及调整，版本化保留评估参数，不能在客户端偷偷训练产生不可同步结果。

## 需要 Owner 最终裁决的硬项

1. 手写涂改的存款收益阶梯与固定存款期限；真实息率不作为默认值。
2. 投资六种骰面回报表以及理财/风投/股票 5/4/3 期的具体结算方式。当前期限是原稿候选，收益表默认禁用。
3. 四块以上资产借款额度、是否要求抵押资产锁定、逾期费和债权优先顺序。
4. 纸本 GO 经过 ¥1000/恰好到达 0 vs 现行 GO ¥200；2 房升旅馆 vs 4 房升旅馆，仍按原已验证棋盘逻辑，暂不改变，以免破坏经济平衡。
5. 8 枚星星完成轮次时赢家自动获得旅馆的产权/建造门槛不清；现阶段只保留纸本计算助手，不将虚拟奖励插入真实棋盘。
6. 活期未确认利率时“本金可原额取回”的默认决定、到期提前还款、玩家完整回合为 1 期等属于本轮工程判断，可由 Owner 后续复核。

## P5 保留治理

本批代码只能进入 `dev/veilopoly:VEILOPOLY_DEV/**`，不修改 VeilLink main、传输层、Protocol 4、VLGM1、SQLite V8、IPA 或 Action。真实宿主全屏转屏仍需单独 P5 授权。旧引擎/联机的消息字段添加选项需进行版本化 handshake，不应当作线上兼容既成事实。
