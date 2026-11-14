# ECLIPSE R12 — 真正关联搜索的棋盘分支动画

## 用户要求和实现

不再播放无意义的随机粒子光场。通过一个可观测、不会修改决策结果的原生 `GomokuBot.chooseMove(... onExploredLine:)` 回调，在 **真实搜索器确实尝试并合法应用**落点时输出探索事件：

- `[first]`：根候选经过真实 `GomokuState.apply`，绘制空心虚拟棋子
- `[first, reply]`：搜索器对对手回应进行了真实 `apply`，细线由第一点延长到第二点，再显示空心虚拟棋子
- `[first, reply, continuation]`：搜索器实际搜索第三手，延长第二条线并圈出第三个虚拟棋子

此回调**不**读取/修改评分、学习权重、战术安全门、计算预算，也不改变最终落子。真实分支 1.35 秒内自然淡出，而不是永久留在用户的落子棋盘。

## 游戏内控制

五子棋 → **训练与高级设置** → **棋盘思考可视化**（独立开关）

- 存储键：`VeilLink.Gomoku.EclipseTraceEnabled.v1`；默认关闭，用户明确开启后跨局保留
- 不影响“深度搜索”开关或实际棋力
- 只在 AI 真正执行搜索、`isAIThinking` 且 `eclipseSearchStartedAt != nil` 时显示
- 当前完整对局未结束仍无赛后棋谱/落点指南；人类回合和 AI 退出瞬间立即清空事件
- 强制验证 sessionID、真实 `GomokuState.moveCount`、UUID token、逐手合法性及棋子轮换
- 所有触摸仍由原 `VeilBoardTapSurface` 接收，Canvas `.allowsHitTesting(false)`
- 其他游戏（中国象棋等）不启用该可视化，不影响 Grok bot

## 渲染方式

- 沿用现有 VeilLink 原生的 `VeilTheme`，不单独设品牌主题
- 细线在连续两个棋盘交叉点之间逐帧增长，空心棋子为虚线圆环+半透明填充，明显区别已落子的实体棋子
- 每条真实分支使用少量现有主题色：`goldBright / paleMetal / success / mutedGold`
- 限制事件最多 20 次/秒、最多 14 条、最多三手；同一根候选真实探索下一手时允许覆盖之前仅有一手的显示，以免限流失去连线
- iOS Low Power 降低刷新率；Reduce Motion 直接显示静态结果，无快速连线
- 原来随机粒子 `VeilEclipseThoughtPattern.swift` 不再被这份完整产品候选补丁新增；在 Inbox 留有旧提案文本供历史审计

## 无真实事件时的处理

如果当前选择独立 JS PVS/VCF，引擎不产生上述原生 `GomokuBot` 回调，**不得**用随机路线模拟；保持无棋盘线条。与其他 Agent 的 V9/V10/R5/R11 计算栈融合时，只有真实有效的原生搜索事件才能驱动本功能，不能把单次终局选择反推成“曾搜索过的路线”。

## 代码交付

同一个 Inbox PR **#208**，不创建新的重复 PR。主要变化：
- 新增 `FILES/VeilEclipseSearchTraceStore.swift`
- 重写 `FILES/VeilEclipseBoardThoughtField.swift`
- 新增 `TESTS/R12SearchTraceTests.swift`
- **完整 `PATCH.diff` 重新根据真实当前 main 源码生成**：4 个现有产品文件（`GameLobbyView`、`LocalAIGameController`、`MiniGameViews`、`GomokuBot`）以及 8 个完整新增 Swift 文件
- 复用 R10 一局一档和 R11 黑底快速滚动仪表盘

## 本地验证和未完成事项

- Swift 6.2.1 Linux `-swift-version 6 -warnings-as-errors -O`：新搜索事件验证 **33/33** 断言通过
- 先前四套既有测试本轮重跑：R10 39 + 公平对局 18 + R9 会话 35 + R11 黑底仪表盘 413 = 505，通过；合计 **538** 次断言
- SwiftUI 新棋盘动画与相关 R11 组件的 **Swift 5 语法解析通过**，**不是 Xcode/iOS 类型检查**
- 完整 `PATCH.diff` 已用原始真实 `main` 文件文本逐块校验：**12 个文件、35 个补丁区块**，上下文行全匹配，所有新增源文本在校验时匹配完整候选源码
- 未执行实际 Xcode/XCTest、真机 iPhone/iPad 触控和持续计算时能耗测试；正式产品、main、IPA 未更新
- 与 #193/#196/#199/#206/#207/#209/#210 的搜索入口、难度/预算及 `GomokuBot` 签名存在跨 Agent 重叠，必须由 Integration Governor 审核实际应用顺序

## 设计原则

绘制的线条**确实对应 AI 所访问的搜索假设**，但不是“最优解建议”。它只在轮到 AI、且玩家无法落子的时候临时显示；这比随机粒子更诚实，同时最大限度维持原本约定的不提示玩家。
