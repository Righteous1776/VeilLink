# 发给 Kimi 的当前任务书 · Veilopoly Visual Lane V1

你是 `Veilopoly` 的 **Visual & Asset Lead（视觉、素材、2.5D 建模与渲染规格负责人）**，与 ChatGPT 的 Swift 工程线**并行协作**，不是它的替代者。

## GitHub 工作位置（你只需定位，不需要直写）
- 仓库：`https://github.com/Righteous1776/VeilLink`
- 分支：`dev/veilopoly`
- 开发区：`VEILOPOLY_DEV/`
- 协作协议：`VEILOPOLY_DEV/COLLABORATION.md`
- 你的交付通过 Owner 传给 ChatGPT，由 ChatGPT 导入分支和审计。**禁止将提交误报为已推送 GitHub**。
- 旧规范：`VEILOPOLY_DEV/Veilopoly/docs/{GAME_DESIGN,MODELING_SPEC,RENDERING_SPEC}.md`（现已在分支直接可读）；也可以使用 Owner 先前给你的策划 ZIP。

## 你的核心任务

1. 负责 UI/2.5D 整体视觉资产，遵守 `RENDERING_SPEC.md` L0–L7 与 12–15° 桌面倾角；按 40 格、4 棋子、房屋/旅馆、骰子、卡牌、金额特效建立布局规范。
2. 整理 Kenney CC0 素材：去除重复，固定 4 个 token、6 张骰面、2 叠卡牌背、房屋/旅馆与清晰度可控的 iPhone/iPad 精灵资源；SFX 清单与触发事件必须对齐 `RENDERING_SPEC.md`。
3. 对游戏体验补齐实际可用的**状态和分镜**：ROLL/MOVE_ANIM/TILE_RESOLVE/BUY/AUCTION/MANAGE/END，以及交易、坐牢、破产、结算屏。
4. 给 ChatGPT 可直接用于 SpriteKit 的标注：每个图层/对象名、尺寸、锚点、坐标系、zPosition、裁切/atlas、颜色和 1x/2x/3x 建议。
5. 定义动画时间轴及快进落点，不修改 Move/Effect/GameState。每次动画只触发一次完成事件，由 ChatGPT 实现 coordinator ack。
6. 做清晰、耐看、适合夜色玻璃/精致桌游氛围的 iPhone 主版和 iPad 横屏适配；先保证可读性、触摸命中区和帧率，再考虑视觉效果。
7. 对于原规格未确定的正式 32 张卡牌、竞拍限制等，只列问题与建议，**不要擅自发明为最终规则**。

## 首批交付顺序

**K1 · 资源与视觉 API 冻结：** `ASSET_MANIFEST.json` + `SPRITE_MAP.json` + `LAYOUT_SPEC.md` + `ANIMATION_TIMELINE.md` + 关键 UI 参考图（iPhone/iPad 各一）；先固定 alias，保证工程对接不再重命名资源。

**K2 · 场景资产：** 棋盘底纹、40 格组件、4 棋子/影子、骰子 6 帧、房屋/旅馆、卡背、图标（尽量合图并分辨率适配）；原始文件和可直接使用的导出图分目录。

**K3 · 交互视觉：** 买地/拍卖/交易/建造/卡牌/结算等 SwiftUI 面板设计、状态图、动画/声音时序和 accessibility 对比度标注。

**K4 · 联合验收：** 根据 ChatGPT 的 iOS 编译/触摸/帧率反馈调整资源和模型；所有修订按版本差异交付。

## 交付文件结构

```text
Veilopoly_Kimi_K1_v1.zip
├── MANIFEST.md                 # 版本、修改摘要、依赖、资源总量、遗留问题
├── ASSET_MANIFEST.json         # path, alias, license, original_url, sha256, bytes, dimensions
├── SPRITE_MAP.json             # 与 SwiftUI/SpriteKit 使用名一一对应
├── docs/
│   ├── LAYOUT_SPEC.md
│   ├── ANIMATION_TIMELINE.md
│   ├── VISUAL_QA.md
│   └── SPEC_QUESTIONS.md
├── previews/                   # iPhone/iPad 示例及关键弹窗参考图
├── assets/                     # 仅生产所需的精简 CC0 资源
└── sources/                    # 可选：源模型/矢量图、原始许可证明
```

不得交付缺来源的商业游戏素材、不可验证许可的大型素材、修改过的系统文件、代码签名文件或模型权重。**不要压成“只有 PNG 没有索引”的资源包**。

## 固定接口与已知资源命名

ChatGPT 当前 SpriteKit 资源名称：`pawnBlue`、`carRed`、`shipGreen`、`planeYellow`、`die1..die6`、`house`、`hotel`、`cardChance`、`cardChest`；声音 `diceShuffle`、`diceThrow`、`moveClick`、`purchase`、`cash`、`drawCard`、`build`、`mortgage`、`trade`、`jail`、`bankrupt`、`turn`。以上名称可增加，但需给出旧名映射，避免断链。

精确定义的视觉工程权属于 Kimi，Swift 引擎与项目入库权属于 ChatGPT；规格裁决与发布权分别属于 Owner 与治理流程。

## 当前可直接引用的工程资产（2026-11-06）

- GitHub 源码已同步；`VEILOPOLY_DEV/Veilopoly/Package.swift` 可见。
- 规格直接阅读 `VEILOPOLY_DEV/Veilopoly/docs/GAME_DESIGN.md`、`MODELING_SPEC.md`、`RENDERING_SPEC.md`；未定项见 `SPEC_DECISIONS_REQUIRED.md`。
- 已有 14 张 PNG 与 12 个 WAV 放在 `VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources/`；既有别名不要无映射重命名。
- 资源 SHA-256、字节大小与 Git Blob SHA 位于 `VEILOPOLY_DEV/Veilopoly/docs/RESOURCE_INTEGRITY.json`。
- 最新源码入库与本地验证记录见 `VEILOPOLY_DEV/CHECKPOINT.md`，iOS 渲染尚未验收。K1 请优先冻结新的视觉 API、Sprite Map、iPhone/iPad 布局和素材来源，不要重新实现 Swift 引擎。

## K1 补充：横屏全屏与胶囊规范（2026-11-06）

- Owner 明确要求 **真实横向全屏**（不是竖屏页面中的小横板）。主程序现已在独立 P4 Swift Package 实现横屏全屏 presentation 代码，实际 VeilLink 主程序接入属于 P5，尚未授权。
- 棋盘左、操作 HUD 右；四棋子、40 格均可见；不得设计必须在整页上下滑动才能看完的布局。参考 `Veilopoly/docs/LANDSCAPE_PRESENTATION.md`。
- 右上角胶囊：左 `•••` 更多，右圆环退出；由 ChatGPT 使用 SwiftUI 矢量绘制，**Kimi 无需额外为胶囊建模**。可给色彩与间距建议，但不要强制覆盖触摸/VoiceOver 的 46×44pt 最小命中区。
- 临时材料/资源审核清单：`Veilopoly/docs/ASSET_GAP_REGISTER.md`，已将 14 PNG/12 WAV 标记为已有。其它列为**待核对**，不是已确认缺少。
- **Owner 将先上传 Kimi 已制作的一部分模型**。收到并审查已完成内容前，不输出终版缺失清单，不重复建模；当前优先准备模型版本、alias/尺寸、素材出处、许可证、移动端导出方案。
- 提醒：Owner 参考截图包含个人信息，不把原图加入公开仓库；只按胶囊语义与外形实现。

## K1 已接收，下一项唯一视觉任务：K2 横向全屏差量交付

已将 `Veilopoly_Kimi_K1_v1.zip` 实际解包写入 `INCOMING_ASSETS/KIMI_K1_v1/`，含两张既有预览、4 个 SVG 源、骰子图集、备选卡背、音频、JSON/MD 规格；原包保持不变。可直接访问 `VEILOPOLY_DEV/Veilopoly/docs/KIMI_K1_INTEGRATION_REVIEW.md` 查看审计结果。

**优先读取并按其执行：** `VEILOPOLY_DEV/Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md`。新增最高优先级是 iPhone 横向全屏 + 微信小程序式右上角双段胶囊的视觉样张和各阶段横屏操作面板，不能继续用 K1 竖屏主稿替代。原有 14 PNG +12 WAV 和 K1 新增贴图已存，不要重复造轮子。

K1 内容还有 **2 项旧资源 SHA-256 记录错误**（`die4.png` 和 `mortgage.wav`，实际二进制无须重做）、四个 SVG 缺失 `viewBox`、骰子 XML 原始文件名失配（工程侧已修复副本）。修订 K2 manifest 并补充准确原始素材 URL；不必重发未变动的大包。

务必记住：`sources/board.json`、`sources/cards.json` 属于未被 Owner 批准的规则提案；不得因为已有预览就把它们变成引擎正式源。

## K1 已接收，后续请按 K2 增量交付（2026-11-06）

- 已收到 `Veilopoly_Kimi_K1_v1.zip` 并解包到 `VEILOPOLY_DEV/INCOMING_ASSETS/KIMI_K1_v1/`；补充贴图、图集与 WAV 已加入独立 SwiftPM 资源，未触及 VeilLink main。
- **下一任务改为 K2，而非重新制作 K1。** 请直接读取 `Veilopoly/docs/KIMI_K2_LANDSCAPE_DELTA.md`（精确工作项）及 `Veilopoly/docs/ASSET_GAP_REGISTER.md`（已收到/待补对照）。旧 K1 文件仅供源资产/历史设计参考。
- 优先 iPhone **真实横向全屏** 两个机型设计稿：844×390pt 与 852×393pt，配 iPad 1180×820pt。左侧 40 格完整棋盘，右侧状态与操作，右上角微信小程序式双按钮胶囊。现有 iPhone 竖屏预览不得作为主界面直接落地。
- 请补齐四个 SVG 棋子的 `viewBox`/画布尺寸/分层或透明独立 PNG 纹理、棋盘 2.5D 分层 atlas、地产图标、HUD 各阶段样式、深浅色、动画及实际来源 URL；详见 K2 文档。当前骰子六帧/旧 PNG 回退已由 SpriteKit 代码接线，勿再次交相同图集。
- K1 旧 `ASSET_MANIFEST.json` 中 `die4.png`、`mortgage.wav` 的 SHA 与仓库资源不一致；新 manifest 请修正，不要替换正确原资源。
- `cards.json`、`board.json` 属于**候选规则资料**，不得自行宣布为游戏正式规则。出狱卡移出/回牌池冲突由 Owner 裁决后才能修订引擎。
- 每个 K2 增量文件务必给 `alias/path/sha256/bytes/dimensions/anchor/atlas metadata/original_asset_url/license`，注明是 `new`、`updated` 还是 `unchanged-K1`。Owner 转给 ChatGPT 复核后才算入库。
- iOS 16 真机方向、卡片触摸、动画 ACK、音效没有通过 Apple SDK 实测；请不要标记为 DONE。


## K3 · Owner financial rule expansion (2026-11-06)

The Owner has added photographed reference rules for bank loans, deposits, simulated financial products and an alternative property/collectible-star mode. **Do not start coding them in Swift or invent payout tables.**

- Source and ambiguities: `Veilopoly/docs/OWNER_FINANCE_AND_TABLETOP_RULES_20261106.md`.
- Specific Kimi visual assignment: `Veilopoly/docs/KIMI_FINANCE_HUD_REQUEST_20261106.md`.
- After the current K2 landscape full-screen deliverable, provide K3 **finance HUD** preview states: deposits and loan quote, period timeline, virtual product cards, loan collateral badge, original 8-star visual in printed mode. Existing More/Exit capsule stays.
- Financial amounts and rule outcomes must come from provided data or show a clearly disabled/undecided state; no real-money gambling or wagering interfaces.
- Kimi does not change VeilopolyEngine, AI/Net, main, protocols, version/IPA; file manifest and license provenance are required for new visuals.

## P4 UI/UE V2 已有程序化特效，Kimi 请直接精修（2026-11-06）

最新 VFX 对接规格：`Veilopoly/docs/P4_INTERACTION_AND_VFX_V2_20261106.md`。

ChatGPT 已制作事件提示 HUD、地块高亮与速览、真人卡牌确认/AI 自动继续、SpriteKit 地块扩散环、现金浮字及回合/胜利横幅，均为**可以被 Kimi 替换的视觉 fallback**。请 K2/K3 只交付高清美术和规格：`fxTilePulseAtlas`、`fxCashChipAtlas`、`fxTurnBanner`、`fxVictoryBadge`、`fxPawnShadowAtlas`、`uiCardFaceFrame`（可提出别名映射，不改变逻辑协议）。按事件名与最终落点提供 atlas frame/anchor/zPosition/timing、减少动态效果静态帧、许可证、SHA-256。

不要重做已提交的骰子六面图集或主动增加规则玩法；不能将模型资产返回当作 SwiftUI/SpriteKit 的运行通过证据。

## 2026-11-06 · Astra 接手部分 Kimi 视觉工作（避免重复制作）

Owner 最新授权：Astra 不再做源码审计或 SwiftUI 编码，而是为 Kimi **分担批量 2D 美术制作**。具体任务：`ASTRA_TASKS/ASTRA_ART_B01.md`（高品质横屏 HUD、购买/竞拍/交易/银行/结算面板及可用 2D UI 素材），`ASTRA_TASKS/ASTRA_ART_B02.md`（可替换 2D 特效图集和时间轴）。

**Kimi 保留且优先：** 2.5D 棋盘结构/地块立体纹理、四枚棋子源模型与导出、房屋/旅馆模型及透视适配、材质和复杂场景动画；并对 Astra 的平面美术资产提供整体视觉一致性审查。Kimi 不重复制作已经交付验收的 Astra UI 面板/2D VFX；若需要替代或重绘，先由 Owner 裁决。

两 Agent 不直接改 GitHub 产品源码；素材由 Owner 转交 ChatGPT 审核许可证、SHA、别名、性能和 SpriteKit 可用性后入 `dev/veilopoly:VEILOPOLY_DEV/**`。没有上传的 Astra/Kimi 素材不得标为已入库。P5、main、发布、协议及数据库仍不授权。

## Astra B01 v1.1 · runtime 13-asset integration (2026-11-07)

The Owner-authorized Astra B01 visuals now have a first SwiftUI runtime bridge in `dev/veilopoly`: 13 selected assets (action buttons, panel/card skins, event feedback, BUY/BANK/SETTLEMENT tickets and two staged AUCTION/TRADE skins). The original 91-alias set remains preserved under `INCOMING_ASSETS/ASTRA_B01_v1_1`, no Kimi art was replaced. **Kimi should not reproduce these B01 2D panels, tickets, or buttons.** Continue K2 2.5D board/tiles/pawns/buildings and independently deliver renderable assets/complex scene animation, then check color/material coherence with Astra. B02 2D VFX remains a separate pending Astra task.

Actual Apple iOS UI compile, SpriteKit composition and touchscreen acceptance are pending. See `Veilopoly/docs/ASTRA_B01_RUNTIME_INTEGRATION_20261107.md`.


## Astra B01 runtime v1.1 · twenty selected 2D skins (2026-11-07)

Astra B01 first runtime stage has been expanded to **20 selected textures**: primary/secondary button states, four compact player HUD statuses, action/glass panels, error/positive feedback, card face, and five scene hero ticket skins. The latest package is still present at `INCOMING_ASSETS/ASTRA_B01_v1_1/` with original SVG/PNG/source manifests. BUY/BANK/SETTLEMENT tickets now have actual data-bound UI; AUCTION/TRADE hero artwork is staged only pending safe interactive hit overlays. **Do not redo this 2D work**; keep Kimi assigned to board/tiles/pawns/buildings and complex animation. Review aesthetic alignment with the 2D skins when K2 2.5D exports arrive. Astra B02 2D effect frames are a separate future batch. Apple SDK verification remains pending.
