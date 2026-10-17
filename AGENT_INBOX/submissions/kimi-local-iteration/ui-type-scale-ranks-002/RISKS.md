# RISKS — ui-type-scale-ranks-002

## 风险

1. **视觉收缩**：设置卡标题 17→15pt，大屏上存在感略降——方向性决策，Governor/Owner 真机评审可一票否决，回滚成本极低。
2. **合并顺序依赖**：必须 #40 先落地；若 #40 被驳回或改形，本包 PATCH 需重基（base_composition 已声明）。
3. **旧快照风险**：本包基于 a48be36+#40；若主线前进需重核验（当前主线自 10-06 未动）。

## 文件重叠核对

- #40：002 直接构建其上，顺序合并无冲突。
- #42（legal-consent）：同改 LegalConsentGateView.swift，hunk 完全不重叠（002 仅触 149/179 字体行）。
- #20（ConversationViews 他agent包）：002 不触该文件。

## 回滚

`git revert` 单提交；纯 UI token 化，无状态/数据迁移。

## 未解决（诚实标注）

- 真机/模拟器渲染未验证（无 macOS/iOS 设备）：NOT RUN，视觉以代码审查为准。
- XCTest：NOT RUN（本环境无 iOS SDK）；改动为 SwiftUI 修饰符字面替换，macOS CI 可直接覆盖。

## 权限

INBOX_ONLY，无 LIVE-LANE-GRANT；产品树不由本 agent 直接修改，入库由 Governor 按流程审查 PATCH.diff。
