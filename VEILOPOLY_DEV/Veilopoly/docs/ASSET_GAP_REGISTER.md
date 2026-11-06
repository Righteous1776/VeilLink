# Veilopoly P4 · Kimi K1 素材入库与 K2 缺口清单（2026-11-06）

**当前状态：K1_RECEIVED_AND_STAGED / K2_DELTA_REQUIRED。** 本文只按实际收件内容与 GitHub 文件清单统计；K1 源文件已交付不等于可直接在 SpriteKit 上运行。

## 1. 已接收且不应要求重做

| 类型 | 内容 | 当前用途 |
|---|---|---|
| 原始工程资源 | 原有 14 PNG + 12 WAV | 4 棋子、6 骰面、房屋旅馆、两张卡背、12 个声音，运行时基本回退 |
| Kimi K1 原包 | `INCOMING_ASSETS/KIMI_K1_v1/` 下 23 项 | 设计稿、SVG、JSON、XML、原始资源和 SHA 记录，原样留存 |
| K1 追加图片 | `diceSheetWhite.png`、`cardChanceAlt.png`、`cardChestAlt.png` | 骰子图集接线、两套备选卡背（备选卡背尚未成为默认样式） |
| K1 追加声音 | `buildClick.wav` | 由 `buildClick.ogg` 转换；程序音频映射已预留，可试播 |
| 图集映射 | `VeilopolyDiceAtlasMap.swift` 与 `K1DiceAtlasTests.swift` | 6 面 UV 坐标、传统骰面回退；Linux 映射单测通过 |
| 视觉稿 | iPad 横屏管理、iPhone 竖屏主界面、board-layout | 参考稿；**竖屏方案不作为运行时主界面** |
| 规则 JSON | `sources/board.json`、`sources/cards.json`、`sources/rng.md` | 只存为未裁决提案，绝不覆盖 Engine |

## 2. K2 待补内容：按重要性排序

| ID | K2 交付项 | 缺口判断与验收 |
|---|---|---|
| V-K01 | `boardTableDark`、`boardBase`、`boardFrame` | 已有 board-layout 参考图，但没有可直接用于 2.5D SpriteKit 的分层桌面/棋盘底板 |
| V-K02 | `tileProperty8`、`tileCorner4`、`tileSpecial` | 缺正式 40 格纹理图集及各格尺寸、旋转、角标配置；文字应保持程序化 |
| V-K03 | `railroadIcon`、`utilityIcon`、`taxIcon`、`chanceIcon`、`chestIcon` | 未接收到独立的高分辨率图标导出 |
| V-K04 | `token*Sheet`、`pieceShadow`、`pieceHighlight` | K1 4 个 SVG 源文件已有，但无 viewBox/画布尺寸，且每个含 158 个 path；需要独立裁切、透明背景、锚点与多朝向输出 |
| V-K05 | `diceShadow`、`diceGlow` | 骰子六面**已有并已接线**；只补阴影、光照、落地效果及时序规范，勿重复提供同一图集 |
| V-K06 | `houseShadow`、`hotelShadow`、`tileOwnerStripe`、`tileMortgageOverlay` | 房屋和旅馆基础 PNG 已有；需补透视方向、摆放槽位与高光阴影；程序可绘制效果优先避免多余切图 |
| V-K07 | `cardFaceFrame`、`cardDeckShadow`、卡牌翻面样式 | 原卡背及 K1 备选卡背已有；仅需正面模板和翻牌规范，不制作未经裁决的正式卡牌文本 |
| V-K08 | `jailBars`、`passGoFx`、`cashFloatFx`、`bankruptFx` | 缺清晰动画帧/时间轴，也可由 SpriteKit 实时生成，先提交效果规范 |
| V-K09 | `overlayBuy`、`overlayAuction`、`overlayTrade`、`overlayManage`、`overlaySettlement` | K1 iPad MANAGE 参考稿已有；缺 **iPhone 横屏**及其它阶段界面和统一交互组件规范 |
| V-K10 | `boardThemeDark`、`boardThemeLight` | 深浅色材质、对比度、棋盘/控件适配尺寸及多任务窗口适配未完成 |
| V-K11 | 完整 `SPRITE_MAP.json` 增量、texture atlas metadata、锚点与来源清单 | K1 目录内有初版映射，但实际交付图集仍需完整尺寸、转轴、可点击区和明确素材来源 |
| V-K12 | iPhone 真横屏全屏视觉稿 | **最高优先级**：844×390pt、852×393pt；左全棋盘/右可独立滚动操作栏/右上角双键胶囊。K1 竖屏稿仅做历史参考 |

## 3. 不需要 Kimi 制作的项目

- `•••` 更多与圆环退出的胶囊图标、按钮交互、退出确认：现由 SwiftUI 矢量实现，无需 PNG/3D。
- Engine 的 Move/Effect、GameState、RNG、网络协议和 P5 VeilLink 入口：属于 Swift 工程线和后续单独授权。
- 已有的骰子六面、12 个基础 WAV、两张普通卡背：除确有可验证质量提升外不重复提供。

## 4. 已发现的 K1 问题

1. K1 `LAYOUT_SPEC.md` 仍将 iPhone 主版定义为竖屏，与 Owner 的横屏硬要求冲突。
2. K1 `diceSheetWhite.xml` 原始 imagePath 指向不存在的 `sheet.png`；运行资源另存已修正的 `diceSheetWhiteFrames.xml`，原始证据不改。
3. 4 SVG 均缺明确 `viewBox` 与尺寸，不能未经导出验证就替换已有 PNG 棋子。
4. K1 `ASSET_MANIFEST.json` 有两处与仓库已存在资源 SHA-256 不符：`die4.png` 与 `mortgage.wav`，具体见 `KIMI_K1_INTEGRATION_REVIEW.md`；不得据此覆盖原资源。
5. 来源清单仍有仅写 Kenney 目录首页的项目，缺单文件精确出处及可追溯许可证证据。
6. `cards.json` 的出狱卡回牌池规则与 K1 `SPEC_QUESTIONS.md` 建议冲突；Owner 裁决前不得应用。

## 5. 交接要求

Kimi 下一包请提交 **K2 增量**，不重做整个 K1。详见 `KIMI_K2_LANDSCAPE_DELTA.md`；每个素材至少给出 alias、path、sha256、bytes、pixel dimensions、坐标/anchor、许可及来源；模型提供源格式与移动端纹理导出。ChatGPT 接收验证后只提交 `dev/veilopoly:VEILOPOLY_DEV/**`，禁止越权触及主程序、协议和 Schema V8。

## 6. 尚未验收

以上确认的是 **文件存在、静态检查及 Linux 可移植测试**。iOS 16 SDK、真正全屏横屏、触控命中、SpriteKit 贴图裁切方向、动画 ACK、AVAudioPlayer 音效仍需 Apple SDK/设备验证。
