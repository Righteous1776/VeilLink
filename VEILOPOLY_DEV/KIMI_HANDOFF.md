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
