# Codex 原生五子棋规模化训练 — 可执行作业规程 R4

## 0. 强制前置阅读和权限

依次读取根目录 `AGENTS.md`、`AGENT_INBOX/00_READ_ME_FIRST.md`、`01_GOVERNOR_IDENTITY.md`、`GOVERNOR_AUTHORITY.json`、`02_RULES.md`、`03_PROMPT_FOR_AGENTS.md`、`06_ASSET_DROP_POLICY.md`、`ASSET_GRANTS.json` 和 GitHub Issue #6、此文件夹全部 9 项；按 Owner > Governor > Codex 的顺序执行。未得到标注完整范围的 `[INTEGRATION-GOVERNOR][LIVE-LANE-GRANT]` 时**INBOX_ONLY**。训练数据放 Codex 工作者独立临时磁盘/用户指定外部存储；GitHub 的 Inbox 只提交**文本方案/测试/少量示例/哈希索引**。

## 1. 拉取“实际目标产品 Bot”，不要用 main 的旧版

```bash
git clone https://github.com/Righteous1776/VeilLink.git veillink-train-readonly
cd veillink-train-readonly
git fetch origin refs/pull/114/head:refs/remotes/origin/codex-gomoku-pr114
git switch --detach refs/remotes/origin/codex-gomoku-pr114
git rev-parse HEAD
# 最初已知 PR #114 head: 14f2740620c0a73874df1588f146ad0f9a67589c；后续版本变动必须重新审查 diff
git diff --stat e093e7fb7ab0eb9821a014b753ab2bdc27613ec8 HEAD
```

只在**另设工作区**编译训练器，不在产品分支上提交。核查 #114 基于 #113、#113 基于 #112；生成代码时锁定真实 sha、Swift 编译器版本和 Xcode 版本。关键源文件：
`VeilLink/Core/MiniGames.swift` 的 `GomokuState`；
`VeilLink/Agent/Games/GomokuBot.swift` 的搜索；
`GomokuFormationLearning.swift`；
`AdaptiveBoardLearning.swift` 的 `AdaptiveBoardPosition.gomoku`、`AdaptiveBoardLearningSnapshot`；
`NativeGomokuSelfPlay.swift`；
`GomokuBundledNativeSeed.swift`。
`LocalAIGameController.swift`、`GameLobbyView.swift` 是实际接入面。

## 2. 建原生 Swift CLI 训练器（Codex 必须实现并执行）

Linux 没有 UIKit/Combine，但上述纯 Foundation 算法可提取**保持逐字等价**的切片；为类型依赖提供**仅结构层**适配，不许重写棋局选择、走子合法性、胜负逻辑或评分搜索。可参考之前验证成功的 `VeilLink_Gomoku_Native_2000_Training_20261031.zip` 研究包（Owner 侧）和 PR #114 的测试。推荐目录：

```text
gomoku-training-work/
  provenance.json
  engine/                 # 提取自精确 commit 的原生 Swift 核心；保留逐文件 SHA-256
  runner/main.swift       # 运行原生 Bot-vs-Bot
  audit/replay.py          # 独立校验器；绝不负责造棋或代替 Bot
  tournaments/            # 基线 vs 带训练、PVS 可用时加入对照
  checkpoint/             # checkpoint / 分片清单 / 运行日志
  output/                 # 大体积 JSONL、候选种子、校验报告（非 Inbox）
```

编译命令以实际 Swift 模块依赖为准，例如：
```bash
swiftc --version
swiftc -O -o gomoku-native runner/main.swift engine/NativeGomokuCore.swift
./gomoku-native --games 10 --seed 20261031 --out output/smoke.jsonl
python3 audit/replay.py output/smoke.jsonl
```
上述 `--games/--seed/--out` 是 Codex **须实现的 CLI 合约**，**不是宣称现有仓库已提供该可执行文件**。要求新增 `--resume`、`--shard`、`--engine-sha`、`--budget`、`--formation`、`--eval-only`、`--stop-after` 等显式选项；运行无参数可打印 help。必须建立可复现的 test fixture：固定 seed、同一 Swift 引擎 commit、同一预算 => 完整棋谱 SHA 可重复；若 wall-clock deadline 使原生搜索非确定，标记为 non-deterministic 并记录时长，不能偷偷报 deterministic。

## 3. 每一局的真实执行

从一个干净 `GomokuState()` 起始，设置清楚是否存在预置首手；预置首手不能算 Bot 决策。每一步：
1. `currentPlayer` 精确取值，构造位置 hash、记录本侧 mode/预算/learning snapshot id；
2. 调用**真实的** `GomokuBot.chooseMove(in:for:budget:learning:formationPreference:)`；记录选择、搜索 nodes/elapsed；
3. 通过 `GomokuState.apply(index:actor:)` 成功才收录；每手禁止重复棋位和越界；
4. 达到 `winner != nil` 或 `isDraw` 才标记 complete；若命令结束、错误、超时、崩溃则**保留中断记录**但 **不计入 completedGames**；
5. 保存原始棋谱、结果、原生 Bot 决策数、棋局来源、运行身份、种子和 commit；
6. 独立 Python replay 必须用单独实现的规则重放，但不可用它生成或替代棋步。
7. 严格区分 `host/black`、`guest/white` 与真正的人类玩家；**自对弈没有真人**。产品现有 `aiWon=guest`、`humanWon=host` 是兼容枚举名，不代表真的有人赢。

## 4. 阶梯式规模化训练

| Stage | 真实完成局数（增量） | 检验 |
|---|---:|---|
| S0 | 10 | 两色实战落子、复盘零错误、可重跑，不虚增计数 |
| S1 | 1,000 | 每局验证、去重、按黑/白、阵法、搜索预算分组；崩溃重启 |
| S2 | 10,000 | 首手/中盘局面多样性显著高于旧数据；保存外部完整 JSONL |
| S3 | 50,000 | 定期 1,000/5,000 局 checkpoint，质量巡检与策略回滚对照 |
| S4 | 可提议 100,000 | **需资源与评测批准**后继续；不以重复对局冒充新增经验 |

- 在 225 个合法开局点中进行覆盖，**不能只增加 17 / 81 个既有开局种子**；不强制把离谱角落开局与中心开局当成同等强度，各分布需单独展示。
- 在六种 `GomokuFormationMode` 下平衡对照与组合，至少对比 `off`、`automatic`、`bagua`、`attack`、`defense`、`discovery`。黑白双方强度、探索参数、运行预算需记录。
- 原生 `chooseMove` 多数位置排序固定，盲目增加 seed 会重复；Codex 应提出**有边界的合法探索**：随机首手、多方阵法、不同预算、局面开局库、可复现 root candidate 变体。**任何候选随机化或 rollout 策略必须单独标记版本**，不能偷偷冒充没有变动的原生决策；必胜/必防约束不能被探索分支绕过。
- 每个 batch 记录 count、unique_full_games、unique_positions、draw/win、illegal_count、cancelled_count、train-data bytes、per-100-games throughput、estimated CPU/memory，重复率超高要先改善探索质量，再扩大训练量。
- Train/validation/test 以**首手族、开局序列、时间分片、种子族**做隔离，禁止让相同/旋转镜像等价棋局泄漏到验证集。识别重复对局并对称标准化（旋转/镜像）作为**分析辅助**；真实对局数据库是否规范化必须额外设计并跑过兼容回归。
- 50k/100k 阶段不要每局把全历史数据库重编码写盘（O(n²) 风险）；原始对局用 append-only 小批次原子写，学习统计定期增量归并/压缩，建立断点恢复与 checksum 索引。不可在未经授权情况下直接改产品数据库 schema。

## 5. 严格可恢复性

每批次输出不可变 `shard-000001.jsonl` 和 `shard-000001.manifest.json`，包含 `engine_sha`、`start_seed/end_seed`、`complete/unfinished`、`SHA-256`、验证失败数、唯一数、仓位范围、记录数量。生成临时文件，全部复盘通过再原子 rename；checkpoint 只在已验证分片后落盘。恢复需重验上一个 checkpoint 并对 `(engine_sha, seed, side, variant)` 进行幂等去重，不能从“启动次数”计算训练局数。

必须做崩溃恢复测试：模拟第 1、N/2、N 局掉电/kill 后重跑；同一对局不重复入账，已成功原子持久化的数据不能丢。保留原始数据和错误原因，失败不偷偷重置为 0 或伪造结束局。

## 6. 把经验**真正**带回产品

现有 PR #114 的种子格式 `veillink.native-gomoku-real-selfplay.v1` 有 `engineRevision` pin、`count` 上限 **10,000** 和原始文件 **3 MB** 安全上限；单个 50,000 局包**不兼容**，Codex 必须先出**按批、可验证、可恢复、低内存且不重复计数的导入提案**（例如分片验证与持久化后合并），而不是跳过校验、暴力放宽上限。
当前 `AdaptiveBoardLearningStore` 存储的是 JSON 全局字典加 recentGames，规模化追加容易重编码、内存膨胀；也不能直接取代个人历史。`incorporatingNativeSelfPlay` 只做有限的位置权重融合，不是神经网络训练，更不是自我修正源码。**必须经 A/B 回归和用户主动选择**，才允许将新的策略升级为默认；PVS/VCF 原引擎默认保留。

## 7. 验收和最终交付

Codex 至少写回本 Inbox 自己 task 目录里的 `MANIFEST/PROPOSAL/PATCH/TEST_PLAN/RISKS`、`TRAINING_REPORT.md`、`REPRODUCIBILITY.md`、`RUN_SHA256SUMS.txt`、`FAILURE_CASES.md`。大训练包仅提供外部持久存储可访问的文件定位和 SHA，不提交 ZIP、IPA、可执行文件、权重。结果必须标注实际跑完局数/重复局数/有效局数/是否确实导入 App（通常为 NO），不能把“未来计划”写成“已完成”。Governor 核验前 Codex 不合并、不启动发布流程。
