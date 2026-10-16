# RISKS — ui-rhythm-token-foundation-001

## 本次变更风险：低
- 22/25 处为同值重构（编译产物语义等价），3 处为 1pt 级间距收敛。
- 最坏情况：真机上某处 1pt 间距变化在特定字号下产生换行差异——概率低，且回滚是单文件 revert。

## 回滚
`git revert` 单 commit 即可；token 层未被外部依赖前移除亦无成本。无数据迁移。

## 已知限制
- **无真机渲染验证**：所有结论基于源码阅读与门禁。11pt/15pt 字阶、卡片层深、字重层级的进一步统一需要真机评审，本 patch 刻意未做。
- **可见变化极小**：若 Owner 期望"一眼焕新"，本 patch 不是那个——它是让后续焕新可以安全进行的地基。

## 后续任务建议（移交 Owner/Governor 排序）
1. ui-type-scale-ranks-002：真机评审 11/15pt 各面用法后定 terminalValue/cardTitle 字阶并全量采用。
2. ui-legal-gate-polish-002：legal-consent 姊妹包落地后，门页节奏与 token 采用（当前为避免补丁冲突刻意留白）。
3. ui-game-surface-polish-002：PR #26 游戏基座方向明确后再动 MiniGameViews 深层样式。

## 上报（与上次一致，仍待裁决）
1. MaleCNSGraphManager.swift 引用已被 455e550 删除的 bindMaleCNSConsumer，malecns-heavy-validation dual-brain 构建必挂。
2. Issue #8 已在 8bcde6a 修复但仍 open。
3. 新发现：PR #19（ux-tools-agent skeuomorphic budget）提议新增的 SkeuomorphicPerformanceBudget.swift 已存在于 main，疑为陈旧重复提交，建议 Governor 关闭。

## 治理合规自检
- 未触碰 Protocol 4 / VLGM1 v1 / Schema V8 / 身份密钥 / 传输存储 / 恢复机制 / A9-A10 治理 / 发布门禁 / 版本构建号
- 未引入 weights.npz / brain.npz / MaleCNSReference.vfly；asset_grant: none
- 状态仅声明 DROPPED；真机/CI 结果如实标注 NOT RUN
