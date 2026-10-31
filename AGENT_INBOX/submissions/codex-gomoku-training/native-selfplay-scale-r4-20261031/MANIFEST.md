# [AGENT-DROP] Codex 原生五子棋大规模实战训练接管任务

- agent_id: `codex-gomoku-training`
- task_id: `native-selfplay-scale-r4-20261031`
- owner_request: “把信息都塞进 inbox 里面，然后把这个训练的方法也写进 inbox 里面。我现在要用 Codex 来进行大量训练。”
- mode: **INBOX_ONLY**；未发出 LIVE-LANE-GRANT
- status: **DROPPED / 待 Integration Governor 验收**
- base_main_sha: `a0093e93df55fe24300c1da8bae990fc4892392f`
- submission_path: `AGENT_INBOX/submissions/codex-gomoku-training/native-selfplay-scale-r4-20261031/`
- instruction_authority: Owner → Governor `VEILLINK-IG-001` → Codex lane
- coordination: Issue #6
- dependent_readonly_product_PRs: #112 (JS PVS/VCF, `6ec7cb7`), #113 (阵法学习, `d9a93fc`), #114 (原生自对弈, head `14f2740620c0a73874df1588f146ad0f9a67589c`)
- source_native_bot_revision: `bc919b454379841180fb8698a9e0addec87e7af0`
- legacy_generated_pattern_archive: Google Drive `VeilLink_Gomoku_Patterns_14244_20261031.zip` (14,244 **棋形图**；不能计入实际对局)
- product_release_authorized: **NO**
- merge_main_authorized: **NO**
- workflow_dispatch_authorized: **NO**

## 此任务交付

1. `MANIFEST.md` — 基线、授权、范围、状态。
2. `PROPOSAL.md` — 2000 局已验证事实、450 局探索性对照、目标及已知缺陷。
3. `PATCH.diff` — 仅供 Governor 决策的**提议性文档补丁**；不触碰源码。
4. `TEST_PLAN.md` — 实战真实性、棋力、资源、回归和重启验收。
5. `RISKS.md` — 假对局、重复棋谱、偏差、过拟合、引擎降级、数据安全。
6. `TRAINING_PLAYBOOK.md` — Codex 可执行的详细训练阶段、命令与中断恢复。
7. `DATA_CONTRACT.md` — 逐局 JSONL、二进制压缩棋谱、哈希与严格导入规范。
8. `CODEX_HANDOFF.md` — 可直接发给 Codex 的任务指令、优先级与回报格式。
9. `SOURCE_AND_CI_EVIDENCE.md` — 精确仓库路径、PR 依赖、现有成果与可核查证据。

## 工作范围

允许：读取仓库及相关 Draft PR，创建**独立本地工作目录**运行原生 Swift Bot 大规模训练、研究去重/探索/多样性及独立校验；按规约在本 Inbox 子目录提出补丁、门禁报告、训练统计和可复现脚本。

默认不得：改 `main`、直接改产品树、修改签名/发布/工作流、触碰中国象棋或 A9/A10、安全协议、数据库 schema；不得把模型权重、JSONL 大产物、ZIP 或可执行文件提交到 Inbox。

## 完成的定义

不是“跑了多少训练命令”，而是提供 **真实完整局、独立唯一棋谱、局面数、失误数、棋力对照、哈希证据、原生 Bot 参与率、完整恢复证明**。任何无法复现或无法逐手复盘的局数 = **0 有效局**。不擅自声称棋力提升、已集成 App 或已发布。
