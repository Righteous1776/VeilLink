# RISKS — feature-century-program-v1

## 主要风险

- **功能数量幻觉**：100 项规划不等于 100 项上线；状态必须从 PLANNED/CANDIDATE 独立推进。
- **现有 20 项重复**：PR #67/#68 同名类型和路径冲突，必须二选一，不能相加计数。
- **P0 扩散**：#64–#66 触控和数据连续性未完成前，新的全局手势/UI 发布会掩盖根因。
- **协议碎片化**：群聊、回执、任意文件和多链路必须共享一套版本化 capability 协商，不可各自发明 wire。
- **数据库迁移风险**：草稿、群聊、搜索索引、协商缓存必须采用可重复、可中断、可回滚迁移。
- **旧设备性能**：100 项入口不能全部在首页实例化；必须分组、惰性加载和按设备预算。
- **隐私膨胀**：强大功能不等于扩大默认数据访问；索引/AI/诊断均需最小范围和明确清除。
- **extension/高权限**：TrollStore、Widget、Share Extension、Shortcuts 各自有独立容器和 entitlement，不共用“高权限”总开关。

## 重叠与受保护面

- FC-001–020：PR #67/#68。
- 全局触控：PR #64/#65/#66，当前 P0。
- Wire/SQLite：Build 60 已完成 v4 capability + SQLite v10；新增协议必须基于该实现，不能重放旧 PR #56 patch。
- 工具中心入口：PR #65 与 Mission Control 均可能修改 `ToolCenterView.swift`，由 Governor 统一信息架构。
- App 根视图：已整合自适应粒子与生命周期闸门；新全局能力不得重新覆盖旧补丁。

## 明确不做

- 本提交不修改产品源码、版本、workflow、IPA、签名、entitlement、wire、schema、Keychain、A9/A10。
- 不自动 dispatch CI/IPA，不自合并。
- 不声明 100 项已经 APPLIED、VERIFIED、MERGED 或 RELEASED。
