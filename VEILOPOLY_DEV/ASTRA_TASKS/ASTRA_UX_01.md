# ASTRA-UX-01 · 横屏 UE 只读审计

优先级：P0。仓库 `Righteous1776/VeilLink`，分支 `dev/veilopoly`，工程 `VEILOPOLY_DEV/Veilopoly/`。

**只读** `Sources/VeilopolyUI/UI.swift`、`LandscapeLayoutMetrics.swift`、`LandscapePresentation.swift`、`CardRevealGate.swift`、`docs/LANDSCAPE_PRESENTATION.md`。检查 844×390pt、852×393pt iPhone 与 iPad 真横屏、安全区、右上双按钮胶囊、44pt 点击区、独立侧栏滚动、买地/拍卖/交易/银行输入与横屏键盘、卡牌阅读阻塞、VoiceOver 和减少动态效果。

只输出一个 `ASTRA_UX_01_REPORT.md`（Owner 转交 ChatGPT），按严重度 P0/P1/P2 最多 6 个具体可复现问题，每个写：文件/函数、触发条件、最小修复建议、验收方法；再列 iPhone/iPad 手工测试各 5 项。标注静态审查未运行 iOS。

Plus 额度纪律：报告≤1200中文字；只看指定文件，禁止全仓扫读、500 种子测试、图片生成、源码全文粘贴、构建与提交。不得修改 main、dev/veilopoly、协议、版本或发布。Kimi 负责美术建模，你不重复建模。
