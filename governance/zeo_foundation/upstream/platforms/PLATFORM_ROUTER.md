# 五平台 × 六种执行环境 路由

**首先探测具体宿主工具，而不是凭模型名称猜能力。** `read_repo`, `read_git_sha`, `write_files`, `execute_python`, `create_branch`, `draft_pr`, `run_tests`, `persist_artifacts`, `remote_readback` 逐项证实。未知统一当 False。

| 环境 | 默认模式 | 能力提升条件 |
|---|---|---|
| desktop_cli | READ_ONLY → INBOX_ONLY | 实际 Git/Python 工具、Owner/Governor 授权、双学习门完成 |
| desktop_gui | READ_ONLY / TEXT_ONLY | GUI 是否真实绑定 repo，能否回读和执行校验 |
| web | TEXT_ONLY / REVIEWED_RELAY | 连接器的实际权限、文件与版本可见性 |
| mobile_app | TEXT_ONLY / READY_FOR_HANDOFF | 执行宿主可提供可信文件与机器 Gate 证据 |
| remote_agent | READ_ONLY / INBOX_ONLY | 远程隔离 workspace、真实 branch/commit、回读与身份权限 |
| api_automation | READ_ONLY | 经 Owner 限域的凭据与幂等重放控制，不能靠 API 名称授予写权 |

每个平台均需阅读 A 的 `SKILL.md` 和四份必读 references，然后按对应 START_PROMPT 与源适配器中匹配的 `platforms/adapters/...`（B）或 `mobile/platforms/...`（C）补齐。仅对所列的五个平台提供适配。
