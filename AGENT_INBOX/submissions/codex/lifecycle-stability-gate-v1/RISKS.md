# RISKS — lifecycle-stability-gate-v1

## 风险与缓解

- **生命周期语义变化**：集中调度可能改变罕见事件顺序。纯状态机覆盖正常、重复、跳跃和启动前事件；集成必须做真机中断测试。
- **首次 active 增加一次前台处理**：主线依赖 `onChange` 提供初始 active，但 SwiftUI 不保证初始回调。本提案在 Root 首次出现时显式补齐；相关方法应保持幂等，需用日志确认无双启动。
- **内存警告合并过度**：仅合并 2 秒窗口内的重复通知；首次立即处理，窗口后的警告不受影响。
- **Live Activity 时序**：inactive 仍先调用 prepare；直接 background 时也补 prepare。iOS 16.1+ 必须真机验证系统是否允许该罕见路径创建活动。
- **弱引用模型替换**：新 AppModel 会重置 Gate 并重新挂接；目前正常流程只创建一个模型，恢复/失败路径仍需集成测试。
- **MainActor 工作集中**：协调器本身只分发既有同步调用，不新增 I/O；Instruments 仍需确认连续切换没有主线程尖峰。

## 重叠

- 未发现当前 Inbox 提案修改 `VeilLinkApp.swift` 或新增同名生命周期 Gate。
- `VL-MAINT-EDGE-001/swift6-deeptelemetry-notification-sendability-001` 涉及 DeepTelemetry 通知闭包的 Swift 6 Sendable 边界，本提案只调用其现有公开记录方法，不合并或修改该提案。
- 存储中心 PR #50 修改 `AppModel.swift`/`SettingsView.swift`，本提案不触及这些文件，可独立由 Governor 排序。

## 明确不做

- 不修改 A9/A10、协议、数据库、身份或密钥合同。
- 不改 BLE/LAN/Relay 内部重试参数。
- 不改变动画或上帝模式质量策略。
- 不构建或发布 IPA，不触发 workflow，不改版本号，不自合并。
