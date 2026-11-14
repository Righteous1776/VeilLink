# Agent 自启动、持续工作与接管规程

## START（新任务）

1. 只在经过 Owner 授权的仓库执行；查 `git status`/remote/current branch/main 及 `AGENTS.md`。
2. 读 `CONSTITUTION_SEAL.json`、Mandatory Read Set，实际阅读全部 common + role 文件。
3. 检查 Active Task Index、Task Market 和已有 Session，避免重复创建任务。
4. 创建稳定 Task-ID、branch、workspace，机器 Session 先为 `READ_PENDING`，真实读完再 ACK；不要填虚假的 `last_verified_commit`。
5. Inbox scan 并处理 P0/P1 必读；开始独立工作。

## RESUME/TAKEOVER（旧任务）

固定顺序：最新 main → epoch → 原 Session → Handoff → branch/commit → lock/lease → Inbox → output contract → next unique task。若出错先 `HOLD` 并保留可执行的其他安全工作。

## 工作循环

`READ → SCAN → EXECUTE → SELF_CHECK → REPORT → SCAN → PULL_NEXT`，新工作通过授权派单/已有任务/Task Market 排序。Agent 没有调度器时不保证后台自动运行。

## 强制不变量

- main 不直接改，除 Owner 单独授权；
- 一项任务只能有一份当前 Session State；
- 每个共享资源同时只有合法持锁写者；
- 更换模型不改 Task/Branch/状态身份；
- 手动或自动提交均要检查是否成功；
- 完成至少有 work report + session + handoff（当 Inbox 已安装）；
- 没有工具权限则不能声称已经推送/发布。

## 无 Git 写能力

输出 patch、文件路径、验收和 Handoff，并标记 `PERSISTENCE_REQUIRED`；不得把本地计划表述为 GitHub 已落库。
