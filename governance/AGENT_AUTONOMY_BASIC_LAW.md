# Agent 自治与任务认领基本法 — 通用版

## 自治推定与三态

已经完成 Mandatory Read、Inbox scan 且无更高优先级待办的 Agent，可自选自己职责范围内的安全工作。`AUTO_GREEN` 仅适用于 OPEN、独立、无现存 ownership、非 shared mutation、可验收、唯一输出路径、无需新授权的任务；`ACK_REQUIRED` 必须先确认边界/去重；`GOVERNED` 必须获得正式授权与适用 Lock/Lease。

`ACTIVE_TASK_INDEX` 代表已占有/排队/待 Owner 的 Task；`TASK_MARKET` 只代表未占有机会。自选前查二者及 Session、分支、Claim。普通 Agent 在自己分支记录 claim artifact；不得竞态直接改共享 Task Market。重复 Claim 优先最早可核对 durable claim/commit；后到者停下，复用结果或上报差异。

## Workforce Coordinator

Workforce Coordinator 是管理辅助职责而不是更高 Governor；只能对账 Market、标记 BLOCKED/FUTURE/DONE、检测重复、收集空缺，不能自授权限、阻断合法 AUTO_GREEN 或改变已占有任务。

## 不空转但不伪装后台执行

局部 BLOCKER：先报告，写 Session unresolved，再找无依赖安全工作。合法停止：`HARD_BLOCKED/OWNER_DECISION_REQUIRED/PERMISSION_REQUIRED/LOCK_WAIT/PLATFORM_LIMIT/SESSION_LIMIT/NO_SAFE_WORK_AVAILABLE`。停止时持久化状态；除非运行平台确有调度器，不得宣称会自动在未来继续工作。

## 任务结束

`WORK_REPORT → SCAN → 已授权 TASK_ASSIGNMENT / ACTIVE_TASK_INDEX / TASK_REQUEST`。完成一张卡不得悄悄扩大范围，新增工作采用新 Task/successor。
