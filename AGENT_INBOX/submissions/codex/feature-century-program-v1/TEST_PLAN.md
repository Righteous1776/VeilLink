# TEST PLAN — feature-century-program-v1

## 本规划包机器检查

1. `PATCH.diff` 可在 exact Build 61 main 应用。
2. 文档恰好包含 FC-001 至 FC-100，每个 ID 只出现于一条功能定义。
3. 不存在 FC-000、FC-101 或编号缺口。
4. 十个领域各包含十项功能。
5. FC-001–020 标记为 `CANDIDATE-CONFLICT`，没有冒充已整合。
6. FC-021–100 标记为 `PLANNED`，没有冒充已实现。
7. 文档明确 #64–#66 P0 门和 #67/#68 二选一冲突。
8. 分支只修改本任务 Inbox 路径。

## 后续每项功能共同门槛

- Foundation/状态机单测；
- iOS 15 Simulator 编译与全量 XCTest；
- iPhone 7 小屏、触控、内存、低电量和温控测试；
- VoiceOver、动态字体、Reduce Motion、深浅色；
- 权限拒绝/取消/后台/重启/升级/回滚；
- 无秘密、正文或原始私人路径进入诊断；
- wire/schema 项完成新旧客户端矩阵和真实备份迁移；
- destructive/send/export 项完成确认、幂等和故障恢复。

## 当前验证边界

这是规划与验收合同，不包含 100 项产品实现，因此不宣称 Xcode/XCTest 或真机功能已通过。只有文档补丁和目录一致性可在本轮验证。
