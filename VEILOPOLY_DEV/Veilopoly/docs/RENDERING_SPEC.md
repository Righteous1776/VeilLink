# Veilopoly · 2.5D 渲染规格（建模→动画→素材映射）

> 渲染层唯一输入 = 引擎状态快照 G + 广播 Effect 流；**渲染不回调逻辑**。
> 技术栈：SpriteKit（棋盘/棋子/骰子场景）嵌套于 SwiftUI（面板/交易/卡牌 UI）。
> 目标设备：iPhone 为主（VeilLink 当前形态），适配 iPad 横屏；60fps。

---

## 1. 2.5D 呈现定义

| 手段 | 参数 | 效果 |
|---|---|---|
| 棋盘倾角 | 整体场景绕 X 轴倾斜 **12–15°** | 远排格子上缘可见，产生桌面纵深感 |
| 层叠深度 | 每个节点计算 `y` 排序 + `zPosition` 分层 | 棋子走近排时被棋盘边「遮挡」比例自然 |
| 投影 | 棋子/房屋下贴椭圆软阴影（alpha 0.25，偏移 y+6） | 悬浮感，区分于纯平贴图 |
| 缩放透视 | 远排 tile 0.94×、近排 1.0×（近似仿射） | 强化倾角错觉 |
| 微 3D token | 用 pieceXX SVG 渲染为带高光渐变的 SKShapeNode/SKSpriteNode，层高 2px 侧沿 | 棋子立体感（2.5D 核心） |
| 动态光 | 当前玩家回合高亮（格角呼吸灯），焦点摄像机缓慢推近 | 引导视线 |

不采用真 3D（SceneKit 走子路径计算与素材不匹配 2D 精灵）。

## 2. 场景层级（z 轴自下而上）

```
L0 背景桌布（纯色/暗纹，随 VeilLink 主题）
L1 棋盘底板（40 格 tile 网格，角部圆弧路径）
L2 地产标记（色组底色条 + 房子/旅馆图标 + 抵押红色斜杠）
L3 格子内容（铁路/公共事业图标、卡牌角标、税标）
L4 玩家 token ×4（按 y 排序动态 z，同格多 token 自动扇形散开）
L5 骰子 ×2（SKSpriteNode，帧动画）
L6 特效层（金钱飘字 ±¥、星光、监禁栅栏浮层）
L7 焦点遮罩（非当前玩家操作时的暗角 vignette）
---
UI 覆盖层（SwiftUI）：回合横幅、购买/拍卖弹窗、建造菜单、交易面板、卡牌翻面卡、结算画面
```

## 3. 素材映射表（→ 包内路径，均 CC0）

### 3.1 玩家 token（4 色固定映射）
| 玩家 | 文件 | 造型 |
|---|---|---|
| P1 | `assets/boardgame-pack/PNG/Pieces (Blue)/pieceBlue00.png` | 经典人形 |
| P2 | `assets/boardgame-pack/PNG/Pieces (Red)/pieceRed05.png` | 小车 |
| P3 | `assets/boardgame-pack/PNG/Pieces (Green)/pieceGreen01.png` | 船 |
| P4 | `assets/boardgame-pack/PNG/Pieces (Yellow)/pieceYellow03.png` | 飞机 |
备选造型 index 02/04/06–18（含城堡、旗帜、棋子、棋子国王等 19 种）可进「选棋子」UI。

### 3.2 骰子
- 精灵表：`assets/boardgame-pack/Spritesheets/diceWhite.png` + `diceWhite.xml`（6 帧，每帧 128px）
- 独立 PNG：`assets/boardgame-pack/PNG/Dice/dieWhite1..6.png`（结算定格用）
- 双骰并排放置，间距 64pt，落点区 = 棋盘中央空白区（L5 层）。

### 3.3 地产建造标记
- 房屋：`pieceXX` index 13/14（小屋/带顶小屋造型）或 16（塔楼）缩放 0.35×
- 旅馆：index 07（大屋）缩放 0.5×，叠加 `board-game-icons/PNG/house.png` 底标可选
- 摆位规则：每格最多 4 房呈 2×2 微偏移；旅馆居中。均贴 L2 层，带投影。

### 3.4 卡牌
- 牌背：机会 = `PNG/Cards/cardBack_blue2.png`；命运 = `cardBack_green2.png`（OGA 列表 68 种牌背可选）
- 牌面：卡名+效果文字由 SwiftUI Text 绘制（本地化友好），Kenney 只提供背纹与边框。
- 抽卡动效：背面从牌堆（棋盘侧）滑出 → 3D 翻转（SwiftUI rotation3DEffect）→ 正面展示 + 文字逐行浮现。

### 3.5 货币与数字
- 纯 SwiftUI 渲染（文字 + `board-game-icons` 的 `coin/dollar` 图标）；不画纸币贴图，避免视觉噪音。

### 3.6 音效映射（触发 → 文件）
| 场景 | 文件（`assets/…`） |
|---|---|
| 掷骰前摇 | `casino-audio/Audio/card-shuffle.ogg`（轻）或 `boardgame-pack/Bonus/dieShuffle1.ogg` |
| 骰子落地 | `boardgame-pack/Bonus/dieThrow1.ogg` / `dieThrow2.ogg` 随机 |
| 走子每格落点 | `ui-audio/Audio/click2.ogg`（音量 0.4） |
| 买地成交 | `casino-audio/Audio/chips-collide-1.ogg` |
| 收钱 | `casino-audio/Audio/chip-lay-2.ogg` |
| 抽卡 | `casino-audio/Audio/card-slide-3.ogg` |
| 建房 | `ui-audio/Audio/switch6.ogg` + `click5.ogg` 组合 |
| 抵押 | `ui-audio/Audio/switch20.ogg` |
| 交易确认 | `casino-audio/Audio/chips-collide-3.ogg` |
| 入狱 | `ui-audio/Audio/switch13.ogg`（低音） |
| 破产 | `ui-audio/Audio/switch24.ogg`（低音拉长） |
| 回合切换 | `ui-audio/Audio/rollover3.ogg` |

## 4. 动画时间轴

### 4.1 骰子滚动（总时长 ~1.2s）
```
0.00–0.25  骰子从底部弹入（scale 0.6→1.1），dieShuffle 音
0.25–0.85  每骰循环 6 帧旋转动画（0.1s/帧），轨迹沿贝塞尔随机弧线，dieThrow 音
0.85–1.05  减速定格到目标点数（easeOut），弹性缩放 1.0→1.08→1.0
1.05–1.20  高光闪烁一次 → 回调引擎 applyMovement
```

### 4.2 棋子走子（每格 150ms，路径由 seq 长度决定）
```
每格: y 弹跳 (0→-12→0 pt, easeInOut) + x 平移；落格瞬间 click 音 + 微尘土粒子（alpha 0.15 圆点 ×3）
经过 GO：token 经过 L0 左上角时播放 PassedGo 金色飘字「+¥200」
同格冲突：进入已占用格时，既有 token 向两侧滑 12pt（0.2s）
```
总移动 >8 格时启用「快进模式」：前段每格 80ms，末 2 格恢复 150ms。

### 4.3 状态切换通用
| 效果 | 时长 | 曲线 |
|---|---|---|
| 购买地产：色条从格底生长 + 价签弹字 | 0.5s | spring(damping 0.7) |
| 建造：房屋 pop-in（scale 0→1.15→1）+ 阴影淡入 | 0.35s | spring |
| 抵押：斜杠划线（strokeEnd 0→1）+ 整体降饱和 | 0.4s | easeInOut |
| 入狱：token 瞬移到 10 格 + 栅栏落下 + 屏幕微震 3pt | 0.6s | easeOut + shake |
| 破产：token 灰化 → 碎裂粒子 → 资产卡飞散 | 1.2s | 自定义 |
| 回合横幅：顶部滑入停留 1.2s 滑出 | 1.6s | easeInOut |

### 4.4 摄像机
- 默认全景适配（棋盘适配安全区）。
- 掷骰/走子时聚焦当前 token：scale 1.0→1.25 推近 + 平移，走子完成回弹（0.3s spring）。
- 交易/建造进入管理阶段时定格。

## 5. 渲染-逻辑解耦协议（ViewCommand 队列）

引擎 → 渲染的唯一通道：
```swift
enum ViewCommand {
  case diceRoll(DiceAnim)            // 播完后回执引擎
  case tokenMove(player: Int, path: [Int])  // 逐格，可打断快进
  case tileFx(tile: Int, kind: FxKind)      // 建造/抵押/星星等
  case cardShow(deck: Deck, text: String)
  case cashFloat(player: Int, delta: Int)
  case banner(TurnInfo)
}
```
- 渲染器消费队列顺序执行；`diceRoll`/`tokenMove` 播完必须 ack，引擎才推进 phase（保证动画与状态一致）。
- 快进规则：用户点按动画区 → 当前动画跳到末帧并立即 ack。
- 联机收到 Effect 流同样转为 ViewCommand，与本地一致。

## 6. 性能预算

| 项 | 预算 | 手段 |
|---|---|---|
| 场景节点数 | <250 | 复用纹理 atlas（SpriteKit texture atlas 打包四包 PNG） |
| 动画期间 CPU | <30%（iPhone 8 基线） | 粒子预烘焙为序列帧 |
| 内存 | 纹理 ≤60MB | 图标用 tilesheet 大图，房屋用 index 造型 |
| 启动 | 场景构建 <300ms | 棋盘 40 格一次性构建，卡池懒加载 |

## 7. 主题与本地化
- 棋盘底色/格条色支持 VeilLink 明暗主题双套（asset catalog 两套配色）。
- 所有文字走 SwiftUI `.localized`，渲染层无硬编码字符串。
