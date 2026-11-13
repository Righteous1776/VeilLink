# 跨聊天连续性协议 — Session Continuity

**目标：换聊天窗口，不换任务状态；换 Agent，不换工作接口。** 没有模型拥有其他聊天的隐含记忆；连续性由仓库真实文件实现。

## 机器入口和人类入口

`agent_sessions/<TASK-ID>/SESSION_STATE.json` 为机器入口，`agent_sessions/<TASK-ID>/HANDOFF.md` 为补充说明。每个持续 Task 记录：task_id/session_id/predecessor_session_id/profile/lane/branch/workspace、governance_epoch、constitution_version、governance_source_sha、read_attestation、output_contract_id/active_output_mode、status/last_verified_commit、completed、active_files、durable_decisions、must_not_change、unresolved、locks、next_unique_task_zh_cn、takeover_ready、agent_exchange 和 updated_at。

## 接管顺序（严禁跳步）

1. fetch latest main，读取 Seal 和 Mandatory Read Set。
2. 定位当前 Task 的 Session、Handoff、branch，验证 Task-ID 是否相符。
3. 旧 Epoch：`STALE_GOVERNANCE`；重新完成当前 Mandatory Read 和 ACK。
4. 对照 `last_verified_commit`、本地 branch 和远程真实提交；未知 mutation 是否成功时先核验，**不可先重试**。
5. 检查共享资源 Lock/Lease、已过期 claim、现有 Owner/Governor 决策、Active Task。
6. 如已安装 Exchange，执行 scan，处理对本 Task/Profile/Lane 定向的 P0/P1 必读消息。
7. 恢复相同 output contract、durable decisions、must_not_change、已解决与未解决项。
8. 唯一下一任务来自 `next_unique_task_zh_cn`，不得凭新上下文重规划或重复已经完成的修改。

## 写状态的触发

新 Task、重大完成阶段、需要跨 Agent 的决策、共享 mutation 前后、上下文接近上限、交接、Owner 要求、任务完成都要写 Session/Handoff。保存优先级为：baseline → 实际产物 → durable decisions → blocker → next unique task → output contract/Owner overrides。只在聊天里写接管摘要不足以完成 durable 交接。

## 失败态

- `PRE_COMMIT_FAILURE`：可经验证后重试。
- `POST_COMMIT_SYNC_FAILED`：业务 commit 已成功，仅续做状态/消息/索引同步。
- `BASELINE_UNCERTAIN`：HOLD，先查询事实。
- `PERSISTENCE_REQUIRED`：无法写仓库，输出可应用 patch/handoff 并明确未完成。
- `STALE_GOVERNANCE`：重读并 ACK。
- `HARD_BLOCKED`：记录证据、向有权者升级。

## 完成一致性

`complete` 必须同时具备工作结果、引用的 commit、释放/等待的锁、最新 Handoff、待处理 REQUIRED 消息、工作汇报与下一步骤；缺一项标记为非完整结束。
