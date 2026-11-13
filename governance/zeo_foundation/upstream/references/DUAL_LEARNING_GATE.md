# 双来源强制学习 / Dual Mandatory Read Gate

## 必须履行的顺序（没有快捷跳过）

**L0 身份与来源探测**：取得真实 repo、owner 授权方式、default branch 全 40 位 SHA、已有项目 Epoch Seal、AGENT_INBOX Governor Registry；不得把上传附件当成当前 main。项目尚未安装时只允许阅读安装说明及 Owner 初始化。

**L1 B 全量必读**：从当前仓库 `governance/MANDATORY_READ_SET.json` 逐项展开 `common`/角色相关组/`optional_if_exchange_installed`；完整读取仓库实际文件，记录路径、bytes、Git commit、版本、完整度；学习 `governance/SUPREME_CONSTITUTION.md`、Session Continuity、Exchange 协议及回执 Schema（若安装）。`LEARNING_EVIDENCE` 只证明列举证据。

**L2 C 全量必读**：以当前可信分支的 `AGENT_INBOX/07_LEARNING_GATE.md` 为权威清单，按 11 项清单逐文件完整读取；验证每个 `git show <base_sha>:<path>` 的 SHA256；填 `STUDY_RECORD.json`，完整作答 8 项固定核对及 3 个解释场景。

**L3 双门校验**：运行 C 的 `AGENT_INBOX/tools/study_gate.py --repo . --record ...` 获得真实 `STUDY_GATE_PASS`；B 按其真实 `governance_cli.py` 校验 Mandatory Read ACK、Epoch、Session 状态。还要扫描 B Exchange 的强制 P0/P1 消息并按真实投递权限响应。没有命令工具则 `LEARNING_AWAITING_MACHINE_GATE`，没有可信源 `LEARNING_BLOCKED`。

**L4 权限与续接**：确认 C Lane Scope、INBOX_ONLY 边界、main baseline、B lock/lease、C protected surfaces、可用权限、Task-ID 和历史 mutation。任何一项不明，不做仓库写入。

**L5 执行与交付**：做被授权的研究/提案，在适当隔离路径产出 C 六文件；Relay 传 B WORK_REPORT（或仅作 Draft）；机器审查和 Governor 真实接受/应用须单独证据。更新 Session State/Handoff，仅在有授权时落库。

## 机器无法证明的内容

机器只能核验声明格式、校验和、Git 源与固定规则答案，不能保证 AI 已在主观上读懂，也不能替代真实 Owner 许可。**所有报告必须注明未通过的门及确切缺失项**。

## 学证组合输出（追加而不更改原机器格式）

```
[UNIFIED_LEARNING]
task_id: <existing or NEW_PENDING>
trusted_base_sha: <full SHA or UNVERIFIED>
governance_epoch: <verified or UNKNOWN>
b_required: <read>/<total>; b_ack: <real receipt or NOT_VERIFIED>
c_required: <read>/11; c_study_gate: <actual result or NOT_RUN>
exchange_scan: <actual status or UNAVAILABLE>
authority: <verified owner/governor/lane or UNVERIFIED>
state: PASS | PARTIAL | BLOCKED
allowed_mode: INBOX_ONLY | READ_ONLY | DRAFT_ONLY
missing: <exact paths/evidence>
next: <one safe action>
```

`PASS` 仅表示以上两个来源的学习/状态检查都实际通过；**绝不等于允许代码直接写 main**。
