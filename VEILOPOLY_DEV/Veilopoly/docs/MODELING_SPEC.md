# Veilopoly · 解析建模规格（给 ChatGPT 的逻辑实现蓝本）

> 核心思想：**规则引擎 = 确定性纯函数**。所有游戏操作建模为 move 函数
> `(G, ctx, move) → G'`，无任何随机源泄漏到引擎外（随机数由注入的 RNG 提供，种子可同步）。
> 单机与联机共用同一引擎：单机 = 本地生成 move；联机 = move 经消息通道广播、各端重放。
> 引擎输出状态快照供渲染层订阅（见 RENDERING_SPEC）。

---

## 1. 顶层状态

```jsonc
// G: GameState（每次 move 后整体更新，快照可序列化）
{
  "seed": 1729123,               // 全局 RNG 种子（联机时房主生成并广播）
  "rngCounter": 42,              // RNG 调用计数（确定性重放关键）
  "board": { "tiles": [ /* 40 个 Tile，见 §3 */ ] },
  "players": [ /* 4 个 Player，见 §2 */ ],
  "bank": { "houses": 32, "hotels": 12 },
  "chanceDeck":  { "order": [...16], "cursor": 3 },
  "chestDeck":   { "order": [...16], "cursor": 0 },
  "turn": { "player": 1, "phase": "MANAGE", "doubleCount": 0, "rollCount": 0 },
  "auction": null,               // 或 AuctionState（见 §4）
  "trade": null,                 // 或 TradeState（见 §4）
  "pendingCard": null,           // 正在展示待确认的卡牌
  "moveLog": [ /* EventSourcing 日志，见 §6 */ ],
  "winner": null
}

// ctx: 回合上下文（派生量，不入日志）
{ "currentPlayer": 1, "phase": "ROLL|MOVE_ANIM|TILE_RESOLVE|MANAGE|END",
  "allowedMoves": ["rollDice"], "lastRoll": [3, 4] }

// Player
{ "id": 0, "name": "Zeo", "kind": "human|ai", "aiLevel": "balanced",
  "cash": 1500, "position": 0, "jailed": 0,          // jailed: 剩余坐牢回合，0=自由
  "hasJailCard": { "chance": false, "chest": true },
  "properties": [1, 3], "mortgaged": [3],            // 位置索引引用 board.tiles
  "houses": { "1": 2 }, "hotelOn": [ ],               // street -> houseCount / hotel
  "bankrupt": false, "tokenStyle": "pawn|car|ship|plane" }
```

## 2. 棋盘图模型

40 格 = 环形有向图节点数组，`tile.next` 默认 i+1 mod 40；特殊格在 resolve 时改写行为（不入图结构）：

```jsonc
// Tile（联合类型，用 "kind" 判别）
{ "i": 1, "kind": "street", "name": "地中海大道", "color": "brown",
  "price": 60, "rent": [2,10,30,90,160,250], "houseCost": 50,
  "set": "brown", "setSize": 2, "owner": 0, "mortgaged": false,
  "houses": 0, "hotel": false }
{ "i": 5, "kind": "railroad", "name": "铁路", "price": 200, "owner": 1, "mortgaged": false }
{ "i": 7, "kind": "chance" }   // chest / tax / gotoJail / jail / freeParking / go 同构
```

移动 = 沿 next 走 N 步；「Go To Jail」「卡牌瞬移」为图上的**传送边**（跳过中间格不结算、不领 GO 工资——「去 GO」除外）。

## 3. Move 清单（规则引擎唯一入口）

每个 move：`{ type, player, payload, seq }`。前置条件不满足 → 返回错误码，状态不变（引擎永不 panic，只返回 `Result<G', Effect[]>`）。

| # | move type | phase 前置 | 效果 | 主要 Effect（供渲染/广播） |
|---|---|---|---|---|
| 1 | `rollDice` | ROLL | 掷双骰（seeded） | `DiceRolled([a,b])` |
| 2 | `applyMovement` | MOVE_ANIM（内部） | 结算途经 GO 工资 | `PlayerMoved(from,to,steps)`、`PassedGo` |
| 3 | `resolveTile` | TILE_RESOLVE（内部） | 落点结算（租金/抽卡/税/入狱） | `RentPaid`、`CardDrawn`、`Jailed` |
| 4 | `buyProperty` | TILE_RESOLVE | 按标价购入 | `Bought(tile,price)` |
| 5 | `startAuction` | TILE_RESOLVE | 全员拍卖 | `AuctionStarted(tile)` |
| 6 | `bid` | AUCTION | 加价/弃 | `Bid(player,amount)` / `BidFold` |
| 7 | `buildHouse` | MANAGE | 色组集齐且均匀建造规则校验 | `Built(tile)` |
| 8 | `sellHouse` | MANAGE | 半价回收 | `SoldBuilding(tile)` |
| 9 | `mortgage` | MANAGE | 得半价；该地块停收租 | `Mortgaged(tile)` |
| 10 | `redeem` | MANAGE | 付半价+10% | `Redeemed(tile)` |
| 11 | `proposeTrade` | MANAGE | 开交易面板 | `TradeProposed(TradeState)` |
| 12 | `counterTrade` / `acceptTrade` / `rejectTrade` | TRADE | 还盘/确认/取消，原子结算 | `Traded` |
| 13 | `payBail` / `useJailCard` | ROLL（坐牢时） | 出狱 | `Released` |
| 14 | `declareBankruptcy` | 任意欠款时 | 清算链走完后仍不足 | `Bankrupt(player,creditor)` |
| 15 | `endTurn` | MANAGE/END | 切换玩家；doubles 重掷 | `TurnEnded` / `ExtraRoll` |

**统一错误码**：`NotYourTurn / WrongPhase / NoCash / SetNotComplete / BuildUneven / AlreadyMortgaged / TradeMismatch / ...`

## 4. 拍卖与交易状态机

```jsonc
AuctionState { "tile": 1, "active": [0,2,3], "currentBid": 0, "bidder": null,
               "turn": 0, "passedCount": 0 }
// 规则：全员可参与（含出价弃购者）；当前价低于玩家现金上限才可 bid；
// 连续 pass 达 active 剩余人数 → 最高者得；全弃 → 银行收回。

TradeState { "from": 0, "to": 2, "offer": { "cash": 200, "tiles": [3], "jailCards": 0 },
             "request": { "cash": 0, "tiles": [6], "jailCards": 1 }, "status": "open" }
// 原子校验：产权归属、抵押债务转移、现金非负；accept 时一次生效。
```

## 5. 卡牌 Effect 模型（数据驱动）

每张卡 = `{ id, deck, text, effects: [Effect] }`：

```jsonc
// Effect 联合类型
{ "kind": "cash", "amount": -100, "target": "self|allOthers|bank" }
{ "kind": "moveTo", "tile": 0, "collectGo": true }        // 瞬移
{ "kind": "moveNearest", "set": "railroad|utility", "multiplier": 2 }
{ "kind": "moveRelative", "delta": -3 }
{ "kind": "goToJail" }
{ "kind": "jailCard" }
{ "kind": "repair", "perHouse": 25, "perHotel": 100 }
```

## 6. 联机同步协议

- **权威模型**：房主端为权威引擎。每步：权威端执行 move → 广播 `{seq, move, stateHash}`；客户端重放校验 hash，不一致即请求 `resync`（发送方回传完整快照 + 日志截断点）。
- **事件溯源**：`moveLog[]` 只追加；断线重连后补发缺失 seq；新观众只收快照 + 增量。
- **确定性保证**：所有随机走 `seededRNG(seed, rngCounter)`；禁止 `Date()`/`UUID`/浮点比较进入引擎。AI 决策也是纯函数 `(G, playerId, aiLevel) → move`（思考预算内搜索 1–2 层，可延迟）。
- **消息载体**：`vl-game-move { gameId, seq, payload }` 走 VeilLink 应用层消息通道（加密继承传输层）；`vl-game-invite / vl-game-snapshot / vl-game-resync` 同理。**不新增传输原语，不触碰 Protocol 4 / VLGM1 / Schema V8。**

## 7. AI 决策模型

```swift
// 伪代码：分层优先级决策器（全部纯函数）
func decide(G, ctx, me, level) -> Move {
  if ctx.phase == .TILE_RESOLVE && canBuy {
      let v = evaluateTile(tile, G, level)   // 租金回本回合数 + 色组协同 + 现金安全线
      if v > level.buyThreshold { return .buy } else { return .startAuction }
  }
  if ctx.phase == .AUCTION { return bidOrFold(by: valuation, cashReserve) }
  if ctx.phase == .MANAGE && hasCompleteSet && cashReserveOK { return .buildHouse(best) }
  if opponentIsDesperate { return proposeTrade(exploit) }   // 激进档
  return .endTurn
}
```
- 三档参数：buyThreshold / cashReserve / 交易意愿（见 GDD §4）。
- AI 延迟 400–900ms 模拟思考，move 与真人同格式入日志，重放无差异。

## 8. 验收测试基线

1. 同一 seed + 同一 move 序列 ⇒ 所有端 G 逐位一致（hash 相等）。
2. 单机 4×AI 跑 500 局无引擎错误；平均局时 25–45 min。
3. 联机 4 端（2 真人 2 AI）中途杀进程 1 端，resync 后 hash 追平。
4. 破产清算链覆盖：抵押→卖建筑→交易谈判→破产移交。
