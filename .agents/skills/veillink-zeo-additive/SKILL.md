---
name: veillink-zeo-additive
description: VeilLink 的 ZeoStudio 增量治理入口；开始、继续、接管、提案或验收时使用，保留原治理，只补充双学习门、任务续接、消息草稿和可审核记忆。
metadata:
  author: 久野零 / ZeoStudio
  version: 1.0.0
  upstream_entry_version: 1.5.0
---

从仓库根读取 `AGENTS.md`，再读 `governance/ZEO_ADDITIVE_BINDING.md`。现行 Owner/Governor/INBOX_ONLY 和旧提案保持原样。本入口仅针对已安装的增量核心，不自称完整上游包。

1. 核对 main SHA、工作树、Issue #6 与有效身份；分支内新文件不是已生效的 main 法源。
2. 阅读 `governance/MANDATORY_READ_SET.json` 展开的全部原文，及 `AGENT_INBOX/07_LEARNING_GATE.md` 的十一文件。B/C 必须各有真实证据。模板不是已通过的学证。
3. 按原 Task 恢复 `agent_sessions/<TASK-ID>/SESSION_STATE.json` 和 HANDOFF；无确定记录先核验，不重做已提交修改。
4. 用 `tools/governance/governance_cli.py` 检查 B 状态；用 `AGENT_INBOX/tools/study_gate.py` 校验 C 的 Git 对象学证。候选分支只可报告候选验证，不宣称当前 main PASS。
5. 用 `tools/governance/agent_exchange.py scan --task-id <id> --profile <profile> --lane <lane>` 查实际 P0/P1。普通 Lane 只生成草稿，不通过 CLI 擅自写共享 Session、消息或回执。
6. 新提案用原五文件加 STUDY_RECORD.json；运行新增 `AGENT_INBOX/tools/inbox_gate.py --local --submission <root>`。旧提案无需补造证据。main 集成、版本、发布仍由现行 Owner/Governor 控制。
7. 记忆先读 `tools/governance/memory/README.md` 和其 references；私有数据库放仓库外，M07 先审再转正。
8. 输出 `[ZEO-UNIFIED-REPORT]`，明确来源、身份、branch/base SHA、双学习结果、提案与消息状态、实际测试和唯一下一步；无真实证据不得宣称提交、合并或发布。

使用命令和兼容说明见 `governance/zeo_foundation/README.md`。来源明细见同目录 SOURCE_LOCK.json。上游桥接原文在 `governance/zeo_foundation/upstream/references/`，不把其中尚未安装的相对路径当成已存在文件。
