# ASTRA-ART-B01 — 高品质横屏 UI 美术批量制作

**Owner 授权：视觉制作分工；优先级 P0；状态 WAITING_FOR_ASTRA_DELIVERY。**
仓库：https://github.com/Righteous1776/VeilLink
分支：`dev/veilopoly`
工程：`VEILOPOLY_DEV/Veilopoly/`

## 角色与权限
Astra 此次是 **Visual/UI Art Production Agent（2D 界面美术制作）**，明确分担 Kimi 的部分美术工作，**不是 UI Swift 代码编写 Agent，也不是源码审计 Agent**。Astra 不向 GitHub 直接写入；Owner 转交素材包，ChatGPT 负责审查并接入 SwiftUI/SpriteKit。

Kimi 保留：2.5D 棋盘/桌面建模、地块立体纹理、棋子、房屋旅馆的模型与朝向、复杂场景动画。
Astra 独立负责：**横屏 HUD 的 2D 美术皮肤、交互面板视觉、状态组件、图标与设计资产**。不是仅给文字方案。具体 SwiftUI 点击行为、引擎、协议和系统退出逻辑仍归 ChatGPT。

## 精简参考阅读
只读 `Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md`、`Veilopoly/docs/ASSET_GAP_REGISTER.md`、`Veilopoly/docs/KIMI_FINANCE_HUD_REQUEST_20261106.md` 和 `Veilopoly/Sources/VeilopolyUI/UI.swift` 的现有布局部分。**不得扫描整个 VeilLink 仓库**，不重做 K1 已有骰子面、4 棋子 SVG、卡背和 12 WAV。

## B01 实际美术交付（一个批次）
1. **统一横屏 HUD 美术规范**：面板底纹/边框/高光、主要/次要/禁用按钮、金额与状态徽章、浅色小范围备用；色彩 Token、边角、可伸缩切图及 9-slice 定义。
2. **五个可用的横屏操作界面视觉稿与可拆分资源**：买地（BUY）、拍卖（AUCTION）、交易（TRADE）、银行与模拟投资（BANK）、结算/胜利（SETTLEMENT）。每屏既要整体预览，也要可独立导出的面板/图标/装饰层。
3. **玩家状态 HUD**：4 人资金、当前位置、监狱/破产、当前回合、金融周期提示；重要数字必须由程序渲染，不应烘焙进 PNG。
4. **卡牌阅读弹层与财务反馈皮肤**：卡牌正面框、卡牌弹窗暗化层、正负现金反馈、交易确认/错误/加载视觉状态。
5. **兼容已有双段胶囊**：只做视觉外观样张/设计参数，`•••` 更多与右侧圆环退出的点击逻辑 **不重写**，每按钮实际命中区域至少 44×44pt。

## 尺寸与设计验收
- iPhone 真横屏：844×390pt、852×393pt；另附 iPad 1180×820pt 的适配样张。棋盘占左边完整区域；右侧仅交互栏滚动。不得把棋盘塞进竖屏卡片。
- 高品质数字桌游风格：深海军蓝、灰蓝、青金属与克制的金色；清晰层级和细腻微纹理。不得使用侵权游戏 logo/角色/美术。
- 输出最终可用素材而非只有提案：**可编辑 SVG/矢量源**与透明 PNG/图标导出（如具备文件生成能力），并提供预览图；可复用面板给出 9-slice inset/resize mode。
- 动态文字单独标注字体尺寸与占位，不烘焙游戏内金额/姓名/卡牌文本。
- 按钮点击态 normal/pressed/disabled/loading，状态除颜色外还需文字/图标可区分；横屏键盘不得遮住确认/取消区域。
- 不设计真实金钱充值、提款、下注或现实赌博 UI；游戏里的银行与模拟投资只涉及不可兑换的虚拟积分。

## 文件包与验收
`Veilopoly_Astra_ART_B01_v1.zip`：
`MANIFEST.md`、`ASSET_MANIFEST.json`、`SPRITE_MAP.json`、`previews/iphone-landscape/`、`previews/ipad-landscape/`、`ui/panels/`、`ui/icons/`、`ui/components/`、`sources/`，包含设计参数、资源别名、尺寸、锚点、可伸缩边距、版权来源、文件字节与 SHA-256。
单独列 `NEW/UPDATED/UNCHANGED_K1/PENDING`。无生成文件能力时输出可编辑 SVG 源代码 + 预览图与 manifest，不得伪称已有可用 PNG。

## Plus 额度
**只做 B01 一次性批量交付；不要逐屏反复问确认。** 先做 5 个画面 + 1 套组件/图标，避免十几种风格方案、长篇竞品研究和多次全仓阅读。完成交付即停止，后续精修由 ChatGPT/Kimi 对接。
