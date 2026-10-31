# 证据索引 / 源码定位 / 验证界线

## 仓库

- 主仓库：https://github.com/Righteous1776/VeilLink
- 当前启动时基线 main：`e093e7fb7ab0eb9821a014b753ab2bdc27613ec8`，Codex 每次执行必须重新 fetch 最新 main。
- Draft PR #112：https://github.com/Righteous1776/VeilLink/pull/112 — 第三方许可的 PVS/VCF 引擎，基础 revision `6ec7cb76747cd3c7ab20d7493539e29ae9c2e495`。
- Draft PR #113：https://github.com/Righteous1776/VeilLink/pull/113 — 原生阵法模式、实验性自学习偏好、强制防守；基础 revision `d9a93fc63e0b4909cf6006999eeef13d649eedf4`。
- Draft PR #114：https://github.com/Righteous1776/VeilLink/pull/114 — 原生自对弈控制与训练包；起始 head `14f2740620c0a73874df1588f146ad0f9a67589c`，后续更新请按 PR 实时 head 核查。
- Issue #6：https://github.com/Righteous1776/VeilLink/issues/6 — [INTEGRATION-GOVERNOR] 调度/禁区/冲突仲裁。
- 本地研究侧 `VeilLink_Gomoku_Native_2000_Training_20261031.zip` 保留原始研究数据、Swift harness、独立 Python 复盘器、450 局对照记录、报告；**ZIP 不属于允许提交的 Inbox 文件**。Codex 没拿到时以 GitHub PR #114 的源码及内置种子作为可复现实验起点。

## 逐文件路径

1. `VeilLink/Core/MiniGames.swift`：`GomokuState`，15x15、交替落子、`winner`、`isDraw`。
2. `VeilLink/Agent/Games/GomokuBot.swift`：原生搜索与必胜/必防。
3. `VeilLink/Agent/Games/GomokuFormationLearning.swift`：`off/automatic/bagua/attack/defense/discovery`。
4. `VeilLink/Agent/Games/AdaptiveBoardLearning.swift`：`AdaptiveBoardLearningSnapshot`、position hash、`recordCompletedNativeBatch`、存储/融合。
5. `VeilLink/Agent/Games/NativeGomokuSelfPlay.swift`：产品原生对弈 runner；请检查两侧偏好平衡与结束/取消处理。
6. `VeilLink/Agent/Games/GomokuBundledNativeSeed.swift`：内置 JSON 数据独立复盘和 checksum 验证。
7. `VeilLink/Resources/GomokuNativeTrainingSeed.json`：2,000 局已签入产品 Draft 分支的纯文本种子；SHA256 `9f7ddf5c847d6beb972c5a98ad83daa66df189f82171988ac1da68d6142188e0`。
8. `VeilLink/Agent/Games/LocalAIGameController.swift`：实验功能开关、首次导入、持久化训练计数、独立后台 worker。
9. `VeilLink/UI/GameLobbyView.swift`：用户控制入口。
10. `VeilLinkTests/NativeGomokuSelfPlayTests.swift` 和 `GomokuBundledNativeSeedTests.swift`：真正对局合法性/独立重放/篡改 fail-closed。
11. `docs/GOMOKU_NATIVE_SELFPLAY_R3_20261031.md`：已有训练报告和安全门禁。

## 精确验收口径

- “2,000 已完成” = 在 Linux 上运行与当前 VeilLink 原生 Swift 算法相同的 CLI 核心并经过独立复盘；**不代表用户设备已经执行 2,000 局**。
- “App 已训练 N 局” = 在 App 中确实成功校验并持久化 N 局；PR #114 未发布、用户端尚不能据此声称已训练 N 局。
- “棋力提升” = 对照统计 + 置信区间 + 真实预算/棋色控制，不能由学习档案大小推导。
- “CI 通过” = 同一个 **精确 head SHA** 的 iOS build + XCTest + release unsigned candidate 同时通过；正在排队/被新提交取消不等于通过。
- 不许变造 GitHub 状态、原生搜索节点数量、性能统计或真实跑局数。
