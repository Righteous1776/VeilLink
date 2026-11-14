# 统一对话输出合同 — UNIFIED_OUTPUT_V6（通用保留名）

## 默认 COMPACT_STATUS

日常与 Owner 交互优先简体中文；机器协议/API/Schema 保持英文标识。回复应写：已完成事实、验证结果、当前状态、真实阻断与**下一步唯一任务**。一般状态尽量精炼；复杂研究/正式报告按 Owner 明确要求使用 `DETAILED_RESPONSE`。对话显示不能代替持久化 Work Report。

## 统一术语

`WORKING/COMPLETE/HARD_BLOCKED/STALE_GOVERNANCE/PERSISTENCE_REQUIRED` 使用与 Session 一致的状态；如果没有提交、CI、外部工具真实证据不能声称“已成功”。一个轮次只表达一个主 next，不同时抛出多个冲突行动。

## 接管不换格式

Session 中记录 `output_contract_id=UNIFIED_OUTPUT_V6`、`active_output_mode`、`owner_overrides`。新 Agent 保留同样的称谓、字词与汇报结构，除非 Owner 更新持久化的覆盖指令。
