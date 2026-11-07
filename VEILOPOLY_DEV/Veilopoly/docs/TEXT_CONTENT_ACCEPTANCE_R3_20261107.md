# Veilopoly 文字内容全覆盖 R3 · 接线验收说明

**任务**：`VL-VEILOPOLY-EDITORIAL-COMPLETE-R3-20261107`  
**基线**：`ddeef29db98351feb166c499de267ed04ccac90b`  
**写入边界**：`dev/veilopoly` 的 `VEILOPOLY_DEV/**`。主视觉：象牙白、古金、深青绿。

## 已核对的正式 Swift 内容

| 来源 | 覆盖 | 实际使用位置 |
|---|---|---|
| `VeilopolyCardEditorial.swift` | 32张，机会16／命运16 | 真实抽卡 ID 匹配的卡牌弹窗 |
| `VeilopolyWorldEditorial.swift` | 40格地块故事 | 已选地块栏、地产文书 |
| `VeilopolyWorldEditorial.swift` | 5家公司档案、5种行情、动态停牌/交易量说明 | Codex 股票终端 |
| `VeilopolyCivicText.swift` | 6种动态文书 | 地产、拍卖、银行、交易、债务、胜利结算 |
| `VeilopolyGuideLibrary.swift` | 23篇玩法手册，分4章 | 更多 → 玩法辞典，支持搜索 |
| `GamePresentation.swift` | 26种 `GameError` 的具体处理建议 | 原有游戏操作错误面板，可直接打开玩法辞典 |
| `VeilopolyEventFeedback.swift` | 玩家、地点、资金、债务与自动清算的上下文提示 | 游戏现有即时事件栏 |

所有原创文字位于游戏真实 Swift Target 中，卡片和文书动态显示；不依赖 PDF、外部文案库或另建 WebView。

## 本次封口及正确性修复
- 原先没有自助规则入口，现在新增一套 iOS15 可用的内置可搜索玩法辞典；
- 细化 26 类错误指引，失败后告诉用户如何合法修正输入、恢复阶段或保留异常存档；
- 原股票自动清偿事件缺少代码及股数时不会再显示「-- 0 股」。破产清算、自动偿债、正常交易三种语义分别处理；
- 银行到期、贷款、存款、出狱、房屋出售、债务变现增加实时凭证。所有账面数值均来自 `Effect`／`GameState`。
- README 的旧版 `iOS16+` 文字已改为 `iOS15+` 研发部署目标，明确说明 iOS15 真机尚未验收。

## 特意不虚构
- **卡池及40格价格是临时测试规则**：文案完整不代表全部经济设计已获 Owner 终审；
- **真实 P5 蓝牙/LAN 联机仍未集成**，手册会明确说明；
- **股票仅为虚构模拟标的**，不可当成现实行情或投资建议；
- **自动存档为双槽 best-effort**，突然断电不能保证最后未落盘的高频行情 Tick；
- **原图与 Codex 实装不覆盖**，沿用统一象牙白界面和既有 UI；
- 未经授权不修改 `main`、宿主、协议、工作流、IPA 或签名。

## 验收门禁
- GitHub 回读：关键源码、调用位置、目录和分支基线；内容数量和独立 ID 检查；
- XCTest *源码*：玩法辞典、错误建议、自动清算文字、跨资源覆盖与纯读取状态哈希；
- **Xcode 编译、iOS15 UIKit/SpriteKit/SwiftUI 运行、完整 XCTest、iPhone7 性能和断电恢复尚未运行**。不能称正式版本已上线。
