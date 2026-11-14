# 工作群与档案基本法 — Foundation V1

**Agent Exchange 是通知总线，不是永久会议室。**

日常优先阅读：当前 Task Session/Handoff → CURRENT_DIGEST（导航）→ 本 Task 的 REQUIRED P0/P1 → 当前 Task Index/Market。无需每次重复全量翻阅历史消息；但有针对性必读时必须读取消息原文与 references。

## 反重复公文

同一事实/相同 blocker/同一裁决若无新证据不得反复发布 P1/P0。每个关键阶段一条最新结构化 WORK_REPORT 足够；过期 Epoch、已关闭 Task、已回执消息不自动恢复待办。消息如果在不同 branch 并发创立，需在合并后保持各自 ID，不得覆盖。

## 摘要与归档

`CURRENT_DIGEST.md` 为派生导航内容，可从 Inbox + active tasks 重建。摘要不得错误宣称“某个 profile 全员已读”：凡 REQUIRED 广播消息应逐 Task 检查 receipt。旧消息可以按 YYYY/MM/DD 累积并用版本控制归档，不能静默删除影响审计链的决策/回执。

## 可靠性和可观测性

各 Agent 完成 START/RESUME/TAKEOVER/修改共享状态/收尾扫描时更新 Session 的 last_scan_at、pending_required_messages、blocking_messages、latest_work_report_id/path 和 completion_reported。由登录到具有仓库访问权限的 Agent 执行，不把对方读了消息推断成即时已处理。

## 争议

收件身份、消息版本、收件范围和业务授权发生冲突时优先按最高宪法与已注册 Task/Session 处理，涉及真实共享 mutation 时先 HOLD 并报告；不允许 Inbox 反过来决定谁拥有锁或最新权威数据。
