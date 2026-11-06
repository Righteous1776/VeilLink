# Veilopoly P4 · 素材与建模差异登记（临时）

**状态：PENDING_KIMI_EXISTING_WORK_REVIEW — 不是最终缺失清单。**

用户说明 Kimi 已完成部分建模但尚未上传；不得在查看前要求 Kimi 重新制作或将“仓库中没有”误判为“从未制作”。

## 已有且可识别的项目资源

`Sources/VeilopolyUI/Resources/` 已含 **14 PNG + 12 WAV**（真实资源，详见 `RESOURCE_INTEGRITY.json`）：

- 4 个 token：`pawnBlue`、`carRed`、`shipGreen`、`planeYellow`；
- 6 个骰面：`die1`～`die6`；
- 房屋/旅馆：`house`、`hotel`；
- 卡牌背面：`cardChance`、`cardChest`；
- 音效：`bankrupt`、`build`、`cash`、`diceShuffle`、`diceThrow`、`drawCard`、`jail`、`mortgage`、`moveClick`、`purchase`、`trade`、`turn`。

以上是**可用的初始资源**，不代表达到 Kimi 的 2.5D 模型、图集、分辨率、动画和主题目标。SpriteKit 当前也有程序绘制的简单棋盘占位。

## 暂列审核项（收到 Kimi 已完成模型包后确认哪些真正需要新增）

| ID | 需求 / 候选资源别名 | 目标用途 | 当前状态 |
|---|---|---|---|
| V-K01 | `boardTableDark`, `boardBase`, `boardFrame` | L0/L1 桌布与 2.5D 棋盘底板 | 未见独立贴图，待 Kimi 包审核 |
| V-K02 | `tileProperty8`, `tileCorner4`, `tileSpecial` | 40 格地块的统一图集/角格/功能格 | 程序可绘制占位，待视觉素材 |
| V-K03 | `railroadIcon`, `utilityIcon`, `taxIcon`, `chanceIcon`, `chestIcon` | 地块 L3 图标 | 待 Kimi 包审核 |
| V-K04 | `pieceShadow`, `pieceHighlight`, `houseShadow`, `hotelShadow` | L2/L4 柔阴影和高光 | 待 Kimi 包审核；可程序实现 |
| V-K05 | `diceAtlas`, `diceShadow`, `diceGlow` | L5 骰子旋转、落地和光效 | 6 帧静态骰面已有，附加帧待审核 |
| V-K06 | `tileOwnerStripe`, `tileMortgageOverlay`, `tileUpgradeMarkers` | 地产归属、抵押、房屋层级 | 程序占位已有，待 Kimi 包审核 |
| V-K07 | `cardFaceFrame`, `cardDeckShadow` | 翻牌卡面/卡堆阴影 | 牌背已有，文字由 SwiftUI 绘制 |
| V-K08 | `jailBars`, `passGoFx`, `cashFloatFx`, `bankruptFx` | L6 特效 | 先用程序化 fallback，待 Kimi 包审核 |
| V-K09 | `overlayBuy`, `overlayAuction`, `overlayTrade`, `overlayManage`, `overlaySettlement` | 横向 HUD 面板规范 | SwiftUI 基础面板已有，待视觉稿/切图 |
| V-K10 | `boardThemeDark`, `boardThemeLight` | 主题色与 iPad 适配 | 待 Kimi 包审核 |
| V-K11 | sprite atlas metadata + size/anchor map | 导出与 Swift 引用的一对一索引 | 待 Kimi 包审核 |

## 特别说明：右上角胶囊

`more` 的省略号和 `exit` 的圆环**当前由 SwiftUI/SF Symbols/矢量绘制**，不要求 Kimi 新建 3D 模型或 PNG；Kimi 只需在交付稿中给出与风格一致的轻量颜色/边框/间距建议。

## Kimi 既有成果接收后的去重流程

1. 用户上传现有模型包 → 建立 `INCOMING_ASSETS` 暂存清单；
2. 审查实际文件与格式（PNG/WebP/SVG/GLB/OBJ/USDZ 等）、可否在 SpriteKit 使用、许可证与原始来源；
3. 计算每个文件 SHA-256、尺寸、大小、alias、轴方向/锚点与 iPhone/iPad 导出比例；
4. 对照 V-K01～V-K11 勾除已有物件，不补做相同素材；
5. 更新经确认的最终需求，并由用户转发 Kimi，仅补缺失部分；
6. 任何需要真 3D 的实现方案须先审查是否与当前 `RENDERING_SPEC` 的 SpriteKit 2.5D 技术选择冲突，不在引擎中自行导入 SceneKit。
