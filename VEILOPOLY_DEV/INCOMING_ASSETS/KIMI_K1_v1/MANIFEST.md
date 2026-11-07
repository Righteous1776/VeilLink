# MANIFEST · Veilopoly_Kimi_K1_v1（2026-11-06）

## 版本
- 包名：`Veilopoly_Kimi_K1_v1.zip`（K1 视觉接口与素材映射冻结）
- 交付方：Kimi（视觉/建模线）→ Owner → ChatGPT 审核入库
- 仓库基线：`dev/veilopoly` @ KIMI_HANDOFF（main HEAD `ccafebab`）

## 内容清单
| 文件 | 用途 |
|---|---|
| ASSET_MANIFEST.json | 35 项资产：26 项在库（sha256 与 RESOURCE_INTEGRITY 对齐）+ 9 项新增；含别名/许可/来源/尺寸 |
| SPRITE_MAP.json | L0–L7 层级 zPosition、11 组精灵锚点/尺寸/阴影/iPhone-iPad 缩放、atlas 建议 |
| docs/LAYOUT_SPEC.md | 24u 坐标系、15° 倾角投影、房屋槽位、iPhone 竖屏/iPad 横屏布局、主题色冻结值 |
| docs/ANIMATION_TIMELINE.md | 全动画参数表；全部「一次完成事件」对齐 A11 coordinator ack 契约；快进规则 |
| docs/VISUAL_QA.md | 8 色组对比度评级与文字规则、暗色主题检查、VoiceOver/Dynamic Type |
| docs/SPEC_QUESTIONS.md | A01–A13 对齐与提案（board.json/cards.json 请批为正式源）+ 2 个视觉线新问题 |
| previews/iphone-portrait-main.png | iPhone 竖屏主版（ROLL 状态） |
| previews/ipad-landscape-manage.png | iPad 横屏（MANAGE 建造状态） |
| assets/ | 新增 9 项素材（4 token SVG、dice 精灵表 png+xml、卡背备选×2、buildClick.ogg） |
| sources/board-layout.png | 40 格布局全图（board.json 的可视化溯源） |

## 冻结接口（与 KIMI_HANDOFF 一致，零重命名）
图像：pawnBlue / carRed / shipGreen / planeYellow / die1–die6 / house / hotel / cardChance / cardChest
音频：diceShuffle / diceThrow / moveClick / purchase / cash / drawCard / build / mortgage / trade / jail / bankrupt / turn
新增别名（增量）：diceSheetWhite、diceSheetWhiteFrames、cardChanceAlt、cardChestAlt、buildClick、token{X}SVG（矢量源）

## 变更说明（相对 Owner 持有的策划 zip）
1. 资源从「全量四包」收敛为「在库 26 项 + 新增 9 项」，去掉了 ChatGPT 工程不引用的约 1400 个文件；
2. 新增骰子精灵表（滚动动画用）与卡背备选（设置项预留，默认仍用经典蓝/绿）；
3. 布局坐标从「逻辑 24u」落成「含 15° 倾角的屏幕投影公式 + iPhone/iPad 两套布局 + 主题色值」；
4. 动画规格从叙述升级为参数表（毫秒/曲线/音效逐条），并对齐 A11 ack 契约。

## 素材来源与许可
全部 Kenney.nl（CC0 公有领域）：boardgame-pack、board-game-icons、casino-audio、ui-audio。
原始许可说明：https://kenney.nl/support（CC0 1.0）。可商用、可修改、无需署名（保留致谢为佳）。

## 验证状态
- ASSET_MANIFEST 中 26 项在库 sha256 逐字引用 RESOURCE_INTEGRITY.json（人工比对）；
- 9 项新增 sha256 本地计算（SHA-256，见 JSON）；
- 全部 PNG 尺寸由 PIL 实测；包完整性 testzip PASS。
- NOT RUN：真机渲染（待 ChatGPT 集成后联调）。

## 遗留 / 待裁决
1. A01（board.json 转正）、A02（32 卡）等 13 项见 SPEC_QUESTIONS.md；
2. Q-K1-1 iPad 对坐模式、Q-K1-2 卡牌皮肤——默认不做，待 Owner 决策；
3. 浅色「日间毛毡」主题配色未定稿（视觉线下一轮补）。

## 完整性
包级 SHA-256 见随包文件 `SHA256SUMS.txt`。
