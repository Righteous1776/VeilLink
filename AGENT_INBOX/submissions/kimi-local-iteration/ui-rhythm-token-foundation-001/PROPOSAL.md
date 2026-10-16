# PROPOSAL — ui-rhythm-token-foundation-001

## 诊断（先给结论）

VeilLink 的视觉语言本身已经是好的：配色/动效/面板形状全部集中在 AppTheme.swift 且文档化（"近黑面纱藏信息、暖金只出现在信任与动作周围、动效只有 Reveal/Transit/Resolve 三义"）。真正的问题不在"风格"，在**节奏**：

- **间距无网格**：五个面的 padding/spacing 散落在 2,3,4,5,7,8,9,10,12,13,14,16,18,20 共 14 个值上，兄弟组件之间出现 13/14/12 并存（GameLobbyView 同族 VeilPanelShape 卡片）、9 这类一次性奇值（SettingsView）。
- **字阶无标尺**：字号散布 7~34 共 15 档；但跨面统计发现唯一真正的跨面主流模式是 **10pt bold monospaced** 的终端标签（section header），在 ConversationViews×6、SettingsView×6、GameLobbyView×2、ToolCenterView×1、MiniGameViews×1 共 16 处逐字相同。
- **11pt/15pt 档位各面自相矛盾**：15pt 在 AgentHome 是 semibold、在 ConversationViews 是 bold、在法律门页是 semibold+rounded——这不是"差异"，是尚未决策，不宜由我在无真机环境下替产品拍板。

## 设计决策（K3 方向）

**"Veil 节奏统一"**：不改设计语言一个字，把节奏收敛到可维护的 token 层。分两档处理：

### Layer 1 — 新增 token 层（AppTheme.swift，纯增量，零行为变化）
- `VeilSpacing`：4pt 基线网格 7 级（xxs=4 / xs=8 / sm=12 / md=16 / lg=20 / xl=24 / xxl=32）
- `VeilType.terminalLabel`：10pt bold monospaced，锚定上述唯一跨面主流模式
- **刻意不定义** terminalValue / cardTitle 等更高字阶：现有 11/15pt 用法跨面权重与设计不一致，文档中明示需真机评审后再定档——token 层只承载已验证的共识。

### Layer 2 — 采用与节奏修正（25 处编辑，全部枚举）
| 类型 | 数量 | 说明 |
|---|---|---|
| 同值 token 化 | 22 | 16 处 terminalLabel 字体 + veilCard 4 处 padding(16)→md + VeilStableScrollView 2 个默认参数→md。**视觉零变化**，建立单一事实源 |
| 节奏修正（可见但安全） | 3 | GameLobbyView 兄弟卡片 padding 13→sm(12)×2（同族卡片边缘对齐）；SettingsView 一次性奇值 padding 9→xs(8)×1 |

### 刻意不做（范围纪律）
- 法律门页零改动：同 agent 姊妹 submission（legal-consent-first-sign-ime-commit-001）独占该文件，叠加会产生补丁冲突；门页样式留待其落地后的后续任务。
- 不重排任何布局结构、不动任何文案/遥测标识/accessibility 标识。
- 不碰 local-ci-sim 断言锁定的任何字符串（雷区已逐条核对：'LazyVGrid'/'minimum: 138'/工具标签/'棋局回放'/VeilLinkTrace guard 行等全部保持）。
- MiniGameViews 只改 1 处标签字体：游戏 UI 有大量 sim 锁定的几何断言与在途 PR #26，深入改版另案。

## 无真机环境下的诚实边界
本环境无 macOS/Xcode，SwiftUI 无法渲染验证。因此本 patch 把"可见变化"严格限制在 3 处 1pt 级间距收敛（方向是统一、幅度小于感知阈值），其余 22 处为同值重构。任何更大胆的视觉决策（11/15pt 定档、卡片层深、字重层级）都留给能看真机的人——这在 RISKS.md 中列为后续任务。

## 兼容性
- iOS 15+；纯 SwiftUI 视图修饰层，无 API/持久化/协议变更。
- token 层引用仅 Foundation/SwiftUI 既有 import，未新增依赖。
- 全部现有 XCTest 与 sim 断言字符串保持不变。
