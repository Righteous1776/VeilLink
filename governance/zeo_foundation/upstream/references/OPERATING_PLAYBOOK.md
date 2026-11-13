# 标准操作规程 · Desktop first / Mobile fallback

## 0 · 开始/新会话

1. 如没有可执行宿主，只输出阅读任务及 `CAPABILITY=TEXT_ONLY`，不得暗示已访问仓库。
2. 读取 A `SKILL.md` 和 references；拉取目标可信法源后，完成两个来源的 Mandatory Read；见 `DUAL_LEARNING_GATE.md`。
3. 读现有 `SESSION_STATE.json`，恢复原 Task-ID、owner、branch、workspace、baseline、已有 commit、未确认 mutation、锁、唯一下一步。
4. B Exchange 执行真实 scan：P0/P1 REQUIRED_READ/REQUIRED_RESPONSE 有未完成时，只在其阻断范围内 HOLD；不伪造回执。
5. C Owner/Governor 指定 scope；默认 Lane `INBOX_ONLY`。能力许可不能取代权限许可。

## 1 · 实施与六文件提案

1. 研究和设计在隔离工作区进行；保留来源和受保护面影响评估。
2. 在 `AGENT_INBOX/submissions/<agent-id>/<task-id>/` 准备 `MANIFEST.md`、`PROPOSAL.md`、`PATCH.diff`、`TEST_PLAN.md`、`RISKS.md`、`STUDY_RECORD.json`。不能用未运行的测试充作运行报告。
3. 如有实际 Git 与权限，走 agent-drop branch 和 Draft PR；真实 validator `inbox_gate.py` 通过之后仍仅为 `DROPPED`，不是 `APPLIED`；无写能力则 `READY_FOR_HANDOFF`。
4. Governor 审查重复修改、冲突、权限、License、受保护面、CI、回退后才选择 `ACCEPTED/BATCHED`；源代码修改和验证是后续独立动作。

## 2 · Agent 之间沟通

1. 通知编排使用 B `AGENT_EXCHANGE` JSON Schema，附 Task-ID/Proposal/PR 的引用且不把消息当权力来源。
2. 普通 Lane 仅拟消息，经过授权的 Relay 提交；区分本地草稿 `DRAFT`、已本地写文件 `STAGED_LOCAL`、Git 已提交 `COMMITTED`、远端 push `PUSHED` 和对端回读 `OBSERVED`。
3. `REQUIRED_READ` 在目标 Agent 真实读到消息后才留 READ；`REQUIRED_RESPONSE` 必须有真实关联的 REPLY 才留 RESPONDED。

## 3 · 交付合同 / Output Interface

```
[ZEO-UNIFIED-REPORT]
source: live_repo | uploaded_snapshot | chat_only
role: owner | governor | lane | unverified
platform: kimi | qwen | chatgpt | claude | grok | other
runtime: desktop_cli | desktop_gui | web | mobile_app | remote_agent | api_automation
capabilities_verified: <actually tested, not assumed>
learning_b: pass | partial | blocked (evidence)
learning_c: pass | awaiting_machine | blocked (evidence)
Task-ID: <existing>
Session-ID: <existing or declared>
branch: <verified or unknown>
base_sha: <verified or unknown>
proposal_state: draft | ready_for_handoff | dropped | accepted | applied | verified | merged | released | unknown
exchange_state: draft | staged_local | committed | pushed | observed | none
changes: <actual changed paths or NONE>
tests: <actual command/results or NOT_RUN>
risks: <remaining>
next_action: <one authorized next action>
```

**完成条件**：状态、路径、验证证据互相一致；Session/Handoff 可继续；没有故意漏报 P0/P1，任何对外通知和主线改变均经实际读回与授权验证。
