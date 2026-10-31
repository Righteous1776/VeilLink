# 给 Codex 的直接任务（可整段复制）

你现在接管 VeilLink 的**原生五子棋规模化实战训练**，代理 ID `codex-gomoku-training`，任务 ID `native-selfplay-scale-r4-20261031`。Owner 明确要求：“训练 VeilLink App 里面的棋手程序。训练多少把，就相当于让它获得多少把真正实战。”请**立刻执行代码与实验**，不要只规划或假称已训练。

**治理**：先同步 `Righteous1776/VeilLink` 最新 main，按 `AGENTS.md`、`AGENT_INBOX/00_READ_ME_FIRST.md`、`01_GOVERNOR_IDENTITY.md`、`GOVERNOR_AUTHORITY.json`、`02_RULES.md`、`03_PROMPT_FOR_AGENTS.md`、`06_ASSET_DROP_POLICY.md`、`ASSET_GRANTS.json`、Issue #6 的顺序阅读，再读本提交目录的九项文件。**INBOX_ONLY**，未授予 LIVE-LANE-GRANT，禁止直接更改 main / product tree、发布、修改 workflows、自己合并。所有 GitHub 提交仅限 `AGENT_INBOX/submissions/codex-gomoku-training/native-selfplay-scale-r4-20261031/` 你自己的任务子目录。大数据写工作区外部持久存储，给出索引和 SHA；不进 Git Inbox。

**唯一目标**：使用 PR #114 真实 `GomokuBot.chooseMove` + `GomokuState.apply` 完成真正的 Bot-vs-Bot 对局，把合法真实终局棋谱变成可被 VeilLink 消费的训练证据，且不得降低原 PVS/VCF 默认棋力。原有 2,000 局是 Linux Swift 原生搜索的真实对局、236 种不同棋谱/10,710 不同局面。14,244 张棋形图不是实战。不要把已有 2,000 局重新当作你的新增局数。

**立即执行顺序**：
1. 获取并核查 PR #114 当前 head 和 #113/#112 依赖；记录文件 SHA，不要在 main 的旧版本上训练。
2. 用已核查原生 Swift 代码创建**工作区外部** CLI runner，真正调用原生 `GomokuBot` 每手决策；只有标识为预置的首手可以不是 Bot 决策。实现 seed、独立局级 ID、固定 CLI 选项、分片、复盘、恢复、日志。
3. 立即跑 **10 局 smoke + 1,000 局基线**，记录真实完成数、Bot 决策数、异常/和棋、重复棋谱和局面分布、耗时、源代码/产物 SHA，并在独立 Python 裁判中逐手重放全部对局。
4. 验证后继续 10,000 → 50,000 局，优先提高不同棋谱数和覆盖，避免只把相同套路重复 50,000 次。若 100k 训练需要太大资源，先给预计预算、资源风险和停止条件，不得谎报完成。
5. 对**未出现在训练中的开局序列/对称局面**做双向换色 paired tournament；至少分阶段跑 200/1,000/5,000 配对组，与无训练同原生 Bot 比较，必要时再单独挑战 PVS/VCF，报告积分率和 95% 置信区间。真实棋力退化就不要推广模型，即使训练局数变大。
6. 审查两方都是 Bot 时白方 guest/AI 与黑方 host/human 的旧奖励映射、存储扩容风险、`count<=10000` 和 3MB 种子限制；给 Governor 一份**不破坏玩家记录和不覆盖原引擎**的修复提案，不要未经授权修改 App。
7. 把执行信息、可复现实验、数据文件索引/ SHA、统计、失败样例、训练档案导入方案写进 Inbox 任务目录的 `TRAINING_REPORT.md`、`REPRODUCIBILITY.md`、`RUN_SHA256SUMS.txt`、`FAILURE_CASES.md` 和必备五件套，供 Governor 审核。不得擅动正式版。

**每次回报请用中文且含证据**：原生完成 N 局 / 本轮新增 n 局 / 原生 Bot 实际决策 x 手 / 有效局 n / 不同棋谱 u / 不同局面 v / 无效局 e / 胜负/平局 / 训练侧相同基线对照胜率及不确定性 / CPU-耗时 / 产物 SHA / GitHub Inbox path / 下一阶段。若缺证据，就明确报告“未执行/未验证”，不要把计划当成绩。
