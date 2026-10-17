# PROPOSAL — ui-type-scale-ranks-002

## 目标

承接 #40 的 token 层（VeilSpacing / VeilType.terminalLabel），归一"金色卡片/区块标题"这一真实存在三分实现的字阶。

## 诊断（实读修正旧假设）

旧记录称"15pt 文字标题跨面分歧（AgentHome 15-semibold / ConversationViews 15-bold / Legal 15-semibold-rounded）"。本轮对全部候选点逐一实读上下文后**推翻**：

- AgentHomeView:116、ConversationViews:148/156/609 的 14/15pt 均为 **SF Symbol 图标尺寸**（设置滑杆、工具栏群组/加号、发送箭头），不是文字字阶，不应 token 化；
- 真正的文字标题分歧在"金色强调标题"角色上：Settings 10 处卡片标题用 `.headline`（17pt 语义体）、GameLobby sectionTitle 用 `.headline`、LegalConsentGate 2 处用 15-semibold-rounded 字面量——同一角色三种实现。

## 决策（K3 定方向，Governor 评审）

`VeilType.cardTitle = .system(size: 15, weight: .semibold, design: .rounded)`，锚定法律门页——最新、最完整的正式面，且 rounded semibold 是产品设计语言主线（legal 25pt 标题、Settings:189 title3-rounded、Lobby:49 title2-rounded 同族）。

采用 13 处：Settings 10（外观/安全/协议/数据/图片/AI/触感/蓝牙 8 卡 + A9 健康晶格 + 内核运行模式）、GameLobby sectionTitle 1、Legal 2（token 化，零视觉变化）。

## 刻意不动（均已实读定性）

- **行标题**（text 色 `.headline`：ToolCenter 对讲机/工具格、Lobby 会话行/游戏行）：内容主体角色，17pt 与 15pt 金色分区标签形成"内容 > 标签"层级，合理；
- **状态行**（Lobby:338 statusText 动态色）、**内容标题**（Lobby:447 战报、:481 场景名）：语义各异，不强行归一；
- **mono 微标签家族**（7/7.5/8/8.5/9/9.5pt）：尺寸随角色真实分化（徽章/眉毛/数值），无共识，继续观察；
- 动态类型取舍：产品标题体系本就走固定尺寸路线（legal 25pt、mono 标签群），cardTitle 保持一致；语义体 `.headline` 行标题保留动态类型。

## 兼容性

视觉变化仅限：设置 10 卡与大厅分区标题 17→15pt 收缩并获得 rounded 字形。无行为/数据/接口变化。依赖 #40 先合并（002 的 AppTheme hunk 位于 #40 新增的 VeilType 内）。与 #42 同文件（LegalConsentGateView）hunk 不重叠（#42 改 6/38/232/296/315/371 区，002 改 149/179 行）。
