# VeilLink ECLIPSE R10 · Every Match & Thought Field

**项目：Righteous1776/VeilLink · 基线 main `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`**

针对 Owner 的新需求：五子棋每局都保留独立棋谱；在实际五子棋棋盘上添加快速、密集、随真实思考耗时逐渐增强的抽象多色视觉效果，但**绝不提供任何玩家落点提示**。UI/材质保持 VeilLink 现有五套主题，尤其与截图的「拟物仪器 · 深色」一致。

## 交付物（完整源代码，不是空方案）

- `FILES/VeilGomokuMatchArchive.swift`：独立每局归档，落一手保存一次，重开记录「中断局」，完成时固化胜负。不覆盖原来的续局文件，不设历史棋局总量上限。分页读取、校验、原始损坏文件保留。
- `FILES/VeilEclipseThoughtPattern.swift`：Foundation-only 的无提示装饰光场算法，不接受棋盘或候选点。
- `FILES/VeilEclipseBoardThoughtField.swift`：SwiftUI Canvas/TImelineView，24fps（节能≤12fps），低运动效果静止；从 VeilTheme 继承 4 色，不截获点击。
- `FILES/VeilEclipseIdentityAndTrace.swift`：原主题 ECLIPSE 头像卡、实际搜索计时、逐局历史分页入口、赛后独立只读回放。
- `FILES/VeilEclipseTracePolicy.swift`、`FILES/VeilEclipseTraceSessionGate.swift`：继承 R9 的“对局零提示、搜索会话真伪”策略。
- `PATCH.diff`：建议将上述六份代码加入产品并修改 `GameLobbyView.swift`、`MiniGameViews.swift`、`LocalAIGameController.swift` 的完整源码级补丁。
- `TESTS/`：Swift 6 严格编译可运行的归档、隔离和无提示回放测试。
- `ECLIPSE_R10_Theme_Thought_Preview.html`：可在手机浏览器离线查看、切换五种主题、激活装饰光场、模拟赛后记录的**演示**（演示不包含实时 AI 搜索）。
- `evidence/r10_instrument_dark_thinking.png`、`r10_history_replay.png`：Chromium 模拟截图，非 App 正式截图。

## 验证结论

- Swift 6.2.1 Linux Foundation 模块及测试：**36 + 18 + 35 = 89 项断言通过**。
- 145 盘独立记录的多页读取测试通过；额外的损坏棋谱不会删除或覆盖。
- SwiftUI 组件已语法解析，尚未在 Apple SDK 下做类型检查或编译。
- 浏览器验证 320px、390px、768px，思考光场启停及赛后历史切换无脚本错误/横向溢出。
- `PATCH.diff` 通过**由 `main` 精确代码片段重建的模拟前像**的 `git apply --check`，**不等同于完整主仓库上应用成功**。
- **未合并 `main`、未编译 iOS、未生成 IPA**。需要 Integration Governor 审查与集成权限。

## 使用中与用户交互边界

- 原生搜索开始后才展示真实已用时间。特效的密度仅随已过时间变化，不代表节点数或胜率，更不应为了视觉效果延迟 AI 落子。
- 棋盘效果全部由随机装饰轨迹构成；不读取棋局、评分、建议点、搜索主变。真实战术路径不能投射到玩家当前对局棋盘。
- 完整已落子空间回放只在本局结束后进入只读 TRACE 页面。对局进行时不可借历史菜单查看坐标，避免隐含提示。
- 动画独立于触控判定区，低电量和 Reduce Motion 时主动减负。
- `GomokuMatchHistoryV1` 仅在 R10 正式集成后开始完整积累历史；之前已经被旧版覆盖的棋谱无法凭空恢复。仍在旧续局文件内的最后一局可在迁移时校验并补档。

## 集成顺序

1. 冻结 V9/搜索 R5 与 ECLIPSE R8/R9 的文件重叠；由 Governor 合并一套最终 UI/控制器调用点。
2. 引入归档与纯显示策略组件，单独测试旧续局文件、重开后未完成棋谱、历史记录恢复、容量和数据保护。
3. 接入棋盘无提示装饰 Canvas 与真实计时，测试不同主题、低功耗、VoiceOver/Reduce Motion、热耗。
4. 真机 iPhone/iPad、Xcode XCTest、CI 全绿后合并；不得为了特效故意增大计算预算。

### 2026-11-14 continuation
The archived source and complete advisory patch were updated and reverified. R10 now passes 39 native archive/animation checks plus 18 fair-play and 35 telemetry checks = **92**. Abstract board animation starts only after the controller records the search start. File sizes >128 KB are rejected before decoding; clock rollback is guarded. Source-only PR; Xcode/CI/IPA NOT RUN.
