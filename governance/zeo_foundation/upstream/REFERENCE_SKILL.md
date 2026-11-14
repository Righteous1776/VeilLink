---
name: zeo-unified-agent-foundation
description: 久野零（ZeoStudio）通用多 Agent 治理总入口。将 Task/Session 持久接管、最高宪法和 Agent Exchange 消息回执与 Owner/Governor/Lane、INBOX_ONLY、Agent Inbox 提案门禁、双强制学习证据融合。接管、并行协作、分工、派单、通信、提交与验收时必须使用。
metadata:
  author: "久野零 / ZeoStudio"
  version: "1.5.0"
  package: "A_Zeo_Unified_Foundation"
---

# Zeo Unified Agent Foundation · 强制总入口

> **方案作者：久野零 / ZeoStudio。** 本文件是现有两套制度的适配桥梁，不伪装成现有仓库已批准的最高宪法。

## 0. 先读，不准绕过

1. 全文读取本文件、`references/UNIFIED_CONSTITUTION_BRIDGE.md`、`references/DUAL_LEARNING_GATE.md`、`references/CONFLICT_MATRIX.md`、`references/OPERATING_PLAYBOOK.md`。按所属运行端读取 `platforms/PLATFORM_ROUTER.md`。
2. 接到真实目标仓库后，读取现行 `AGENTS.md`、`governance/CONSTITUTION_SEAL.json`、`governance/MANDATORY_READ_SET.json` 和其中要求的全部法源；另读取 `AGENT_INBOX/07_LEARNING_GATE.md` 的 11 份必读原文，并做明确来源与版本检查。
3. `AGENT_EXCHANGE` 管消息；`AGENT_INBOX` 管提案。不得混淆其命名空间、机器校验与回执状态。
4. 学习链：发现可信来源 → 逐文件读全 → 复述与证据 → 真实本地门禁 → 权限检查 → 任务执行 → 交付验证。不具备真实仓库/执行能力则进入 `BLOCKED`/`DRAFT_ONLY`/`READY_FOR_HANDOFF`，不编造通过状态。
5. 优先还原 `agent_sessions/<TASK-ID>/SESSION_STATE.json` 与 Handoff，维持 Task-ID/branch/baseline/已知决策。`继续` ≠ 新建项目或任意规划。不能确认此前写入是否成功时，先核验，再决定是否重试。
6. 默认 Lane = `INBOX_ONLY`。仅可在该 Lane 自己的 `AGENT_INBOX/submissions/<agent-id>/<task-id>/` 建提案；不能直接写共享产品文件、`AGENTS.md`、治理文件、其他 Lane 或 main。
7. 如需向 `AGENT_EXCHANGE` 投递消息，Lane 默认只产出 `MESSAGE_DRAFT` 并交授权 Relay/Governor 落库；只有经可信授权的写者才允许真实传输。回执不得伪造。
8. 完成必须区分 `DRAFT`, `VALIDATED_LOCAL`, `DROPPED`, `ACCEPTED`, `APPLIED`, `VERIFIED`, `MERGED`, `RELEASED`；每种状态都要有相应回读证据。

## 1. 组件路径

- `components/B_exchange_continuity/skills/zeo-multi-agent-governance/SKILL.md`：原 Task/Session/最高宪法机制。
- `components/B_exchange_continuity/skills/zeo-agent-exchange-inbox/SKILL.md`：Agent Exchange 消息与回执。
- `components/C_governed_proposal/skills/agent-governance/SKILL.md`：Owner/Governor/Lane 权限与集成。
- `components/C_governed_proposal/skills/agent-inbox/SKILL.md`：Agent Inbox 六文件提案与 Gate。

**上述四个技术子模块仍属于原来的两套制度，不凭文件夹数量创设新的审批权。**

## 2. 法源冲突停止机制

任何现有目标仓库批准的、更高位阶的 Owner 决议和保护规则优先于本包默认模板。A 的桥接规范只定义两套机制如何互操作；若无法确定法源层级或两个来源都声称最终写权，则标 `AUTHORITY_CONFLICT=HOLD`，列出条款并交可信 Owner/Governor 裁决，不凭模型偏好合并法源。

## 3. 受控运行

- 推荐先在未安装制度的全新测试目录运行 `python tools/install_unified.py --target <repo> --project-slug DEMO --owner <owner> --dry-run`，再由 Owner 审核运行。安装器只新建，不覆盖，不自动 commit/push/merge。
- 分离安装：B、C 各自目录中独立保有安装器和原测试；详见根 README。
- 可审计交付：机器门禁只验证能验证的内容；没有 Git SHA/读回/权限，则不使用 `PASS`。
- 人类输出见 `references/OPERATING_PLAYBOOK.md`；五平台分别有 `platforms/<name>/START_PROMPT.md`。

## V1.4 任务实战手册（强制入口，按需深读）

在原有必读、现行法源和双学习门之外，先读 `handbook/01_OPERATOR_ENTRY.md` 再开展实操。按任务类型读 `handbook/README.md` 的对应专题，使用 `templates/` 的交接/证据工件与 `tools/contract_lint.py` 审核声明一致性。**lint 不是授权/学习 gate，不能取代真实测试。** 版本变更不自动改变目标仓库 Epoch。

## V1.5 · 编号记忆库与睡眠复盘（必读入口）

新增长期记忆指令 M01（最多 50 条生效）、M00–M09 十个编号库、定期摘要候选 M07 和审核/遗忘流程。开始操作前必须读取 `memory/README.md`、`memory/references/01_MEMORY_ARCHITECTURE.md`、`memory/references/03_AUTHORITY_AND_SCOPE.md`、`memory/references/06_RESUME_ROUTER.md`。

用户明确“记住”须有真实写入权限与来源；睡眠摘要**只能先进入 M07 候选**，不能提升为法源或已完成事实。通过 `python memory/zeo_memory.py --help` 使用工具；无存储能力只能交接 Markdown 草案，不许伪造已保存。详细阶段任务见 `memory/references/15_SKILL_LEARNING_PATH.md`。
