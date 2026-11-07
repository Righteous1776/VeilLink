# ANIMATION_TIMELINE · K1 冻结（v1.0，2026-11-06）

> 参数化动画规格：每个动画**只触发一次完成事件**，由 ChatGPT 的 coordinator ack 接收后推进 phase（A11 契约）。
> 快进规则统一：用户点按动画区 → 当前动画跳到末帧 → 立即 ack。不修改任何引擎语义。

## 1. 全局约定

| 项 | 值 |
|---|---|
| 曲线速记 | `spring(d)` = UIKit/SwiftUI spring damping d；`easeInOut`/`easeOut` 标准 |
| 快进手势 | 点击棋盘任意处；不可打断已 ack 的动画 |
| 音效音量 | 走子 0.4，其余 1.0；全部允许系统静音开关覆盖 |

## 2. 骰子滚动 `diceRoll`（总 1.20s）

| 段 | 时间 | 动作 | 音效 |
|---|---|---|---|
| popIn | 0.00–0.25s | 双骰从底部弹入，scale 0.6→1.1 | diceShuffle |
| tumble | 0.25–0.85s | 每骰 6 帧循环（diceSheetWhite atlas，0.1s/帧），沿随机贝塞尔弧线（幅度 ≤40pt） | diceThrow |
| settle | 0.85–1.05s | 减速定格目标点数，easeOut，scale 1.0→1.08→1.0 | — |
| flash | 1.05–1.20s | 白色高光闪一次 → **ack** | — |

## 3. 棋子走子 `tokenMove`（每格 150ms）

- 每格：水平平移 + 弹跳弧线（峰值 −12pt，easeInOut）；落格瞬间 moveClick（音量 0.4）+ 尘土粒子 ×3（alpha 0.15）。
- 经过 GO（逻辑索引 0 的边）：+¥200 金色飘字（rise 40pt / 1.2s）。
- 同格冲突扇形散开 0.2s spring。
- **快进模式**：总步数 >8 时，前段每格 80ms，最后 2 格恢复 150ms（保留落点反馈）。
- 全部步数播完 → **ack**（一次）。

## 4. 交易/建造/管理（SwiftUI 面板）

| 动画 | 参数 | 音效 |
|---|---|---|
| 购买成交 | 色条从格内缘生长 0.5s spring(0.7) + 价签弹字 | purchase |
| 建房 | pop-in scale 0→1.15→1，0.35s spring(0.7)，阴影淡入 0.3s | build + buildClick（组合） |
| 卖建筑 | 反向 pop-out 0.3s easeIn | cash |
| 抵押 | 斜杠 strokeEnd 0→1，0.4s easeInOut，整体降饱和 | mortgage |
| 赎回 | 斜杠擦除 + 恢复饱和 0.4s | cash |
| 交易确认 | 筹码飞行动画 0.6s（双方面板之间） | trade |

## 5. 事件类动画

| 事件 | 参数 | 音效 |
|---|---|---|
| 入狱 | token 瞬移格 10（0.25s）→ 栅栏落下 0.4s → 屏幕微震 ±3pt ×0.2s | jail |
| 出狱 | 栅栏升起 + token 弹跳 −8pt | cash |
| 破产 | 灰化 0.4s → 碎裂粒子 0.8s → 资产卡飞散 1.2s 总长 | bankrupt |
| 回合切换 | 顶部横幅滑入 0.2s → 停留 1.2s → 滑出 0.2s | turn |
| 抽卡 | 卡背从牌堆滑出 0.3s → 3D 翻转 0.5s → 文字逐行浮现 0.6s（SwiftUI rotation3DEffect） | drawCard |
| 收钱/付钱 | ±金额飘字 1.2s（绿/红） | cash |

## 6. 摄像机

| 场景 | 动作 |
|---|---|
| 掷骰/走子 | 聚焦当前 token：scale 1.0→1.25（0.4s spring 0.8），走子完成回弹 0.3s |
| MANAGE/TRADE | 定格（不漂移），由面板接管视觉重心 |
| AUCTION | 保持全景（所有玩家都是参与者） |

## 7. AI 思考

延迟 400–900ms（规格 MODELING_SPEC §7），期间当前玩家位置显示「思考中」呼吸点；AI 产生的 move 与真人动画序列完全一致。
