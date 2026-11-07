# ASTRA-ART-B02 — 2D 程序化特效美术/动画素材批量制作

**优先级 P1；B01 交付后、Plus 额度允许时再执行；状态 NOT_STARTED。**
仓库 `Righteous1776/VeilLink`，分支 `dev/veilopoly`；工程 `VEILOPOLY_DEV/Veilopoly/`。

## 角色分界
Astra 制作 **2D 贴图特效、序列帧、动态 UI 转场皮肤、时间轴**；Kimi 制作 2.5D 场景、棋子、建筑模型以及高复杂度镜头/材质。ChatGPT 负责 Effect→ViewCommand→SpriteKit 节点和 ACK 接线，不要求 Astra 修改 Swift 代码或引擎。

## 必读（只读三份）
`Veilopoly/docs/P4_INTERACTION_AND_VFX_V2_20261106.md`、`Veilopoly/docs/RENDERING_SPEC.md`、`Veilopoly/Sources/VeilopolyUI/RenderCommands.swift`。不要扫描整个项目。不得重画 K1 骰子六面图集或游戏基本 token。

## B02 交付：六组高质量可替换 VFX
1. `fxTilePulseAtlas` — 购买/建造/抵押的地块扩散环（normal/success/warning）。
2. `fxCashChipAtlas` — 虚拟资金增加/减少、利息到期的轻量粒子与数字浮动背景（金额由 SwiftUI/SpriteKit 绘制）。
3. `fxTurnBanner` — 新回合/双骰/奖励的横屏横幅，支持动态玩家名和文字插槽。
4. `fxVictoryBadge` — 单机胜利/结算徽章及出现/收起帧。
5. `fxCardReveal` — 卡牌翻面、光效、静止后玩家阅读，**动画不能自动关闭卡牌弹层**。
6. `fxBankSettlement` — 贷款获批、还款、存取款和模拟投资结算的非刺激性反馈（不呈现真实货币博彩）。

每组交：可直接用于 SpriteKit 的透明 PNG 帧或 atlas + 可编辑源文件（如 SVG/序列帧设计）、frame size、anchor、zPosition、duration、easing、fps/帧数、内存预算、触发事件、快进落点、Reduce Motion 的静态替代帧、版权许可与 SHA-256。视觉时长建议 150–700ms，骰子已有 1.2s 动画无需重制；**不把完成 ACK 逻辑嵌入素材**。

交付包 `Veilopoly_Astra_ART_B02_v1.zip`：`MANIFEST.md`、`VFX_MAP.json`、`ASSET_MANIFEST.json`、`previews/`、`assets/vfx/`、`sources/`、`docs/TIMELINES.md`。缺失素材必须标 `PENDING`，不能用描述文字冒充实际资产。

## Plus 额度
只做这一批六组效果；避免训练模型、重做棋盘模型、长篇调研和重复制作一堆风格备选。Owner 转交 ChatGPT 审计，待接入成功再决定是否开 B03。
