# A 模式冲突矩阵 · 决议和降级

| 发生条件 | 禁止的错误行为 | 合并版做法 |
|---|---|---|
| B 通用自治 AUTO_GREEN vs C 默认 INBOX_ONLY | Agent 直接写源码 | 可自行挑选低风险任务，修改仅提案，不写共享代码 |
| B `send/receipt` 能修改 Exchange vs C Lane 只准 Inbox 写 | 直接落库消息 | `MESSAGE_DRAFT` → 可信 Relay 核对权限与写入 → 回读；未写入为 `PENDING` |
| B Epoch Seal vs C Governor Authority | 把 Governor 身份当 Epoch Owner | 验证两个权威记录；任何声称越权的身份转 HOLD |
| B `Mandatory Read ACK` vs C `STUDY_GATE_PASS` | 用一份通过代替另一份 | 双重学习、分别保留证据、只汇总交集 |
| B Session State vs C Queue/PR | Queue 替代持久任务状态 | Session 保存工作上下文，Queue 只记录提案审查阶段 |
| `REQUIRED_RESPONSE` vs C 提案验收 | 回复消息后宣告提案通过 | 回执只影响 Exchange，C 状态依 Governor/真实 Git |
| C `LIVE-LANE-GRANT` vs B 保护锁或 baseline 缺失 | 单方授权越过保护 | 双侧都通过才执行；否则 HOLD |
| 手机端缺文件/Git 工具 | 自报已学习/已投递/已合并 | 只做文本草案与 HANDOFF，不生成伪造凭据 |
| 五平台模型能力不同 | 凭平台品牌猜写权 | 对实际工具执行能力探针，按可验证功能降级 |
| 两条法源对同一权力各自声称独占 | AI 自行裁定覆盖 | 写出来源和具体条款，Owner 决定，争议范围 HOLD |
| 两边脚本都想安装 `AGENTS.md` | 后装覆盖先装 | A 安装器生成单一桥接 `AGENTS.md`，不静默覆盖 |
| C 学证绑定原 Git 文件 hash, A 自定义 AGENTS.md | 沿用原包学习 hash | 使用**实际已提交**的桥接 AGENTS.md 重新学习和哈希 |
| 已治理仓库已有相同路径 | 以新版本借口覆盖 | 整次拒绝一键安装，交 Owner 审查差异迁移 |
