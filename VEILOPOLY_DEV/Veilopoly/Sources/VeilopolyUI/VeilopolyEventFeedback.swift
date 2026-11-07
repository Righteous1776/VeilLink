import VeilopolyEngine

/// Text-only fallback cues. Kimi may replace their presentation with animated
/// skins, but the reducer remains the authoritative source for every message.
public enum VeilopolyEventFeedback {
 public static func summary(_ effects: [Effect]) -> String? {
  for event in effects.reversed() {
   switch event.kind {
   case .gameWon: return "终章落款 · 本局胜者已确定"
   case .bankrupt: return "清算公报 · 一名玩家已退出本局"
   case .auctionWon: return "拍卖落槌 · 地产产权已重新登记"
   case .bought: return "地契入册 · 新产权已登记"
   case .built: return "工务回执 · 建筑等级已提升"
   case .soldBuilding: return "撤建收据 · 建筑已售回银行"
   case .mortgaged: return "抵押契据 · 此处暂不收租"
   case .redeemed: return "赎回契据 · 此处恢复收租"
   case .traded: return "契约签署 · 地产与款项已交割"
   case .tradeRejected: return "谈判未果 · 本次提案已结束"
   case .rentPaid: return "租约结算 · 租金已划转"
   case .bankBorrowed: return "银号批复 · 贷款已入账，请留意到期日"
   case .bankRepaid: return "偿款收据 · 本笔贷款已结清"
   case .bankDeposited: return "存款存根 · 银行账本已更新"
   case .bankWithdrawn: return "取款凭证 · 资金已到账"
   case .bankInvestmentOpened: return "投资凭证 · 新一期合约已登记"
   case .bankInvestmentSettled: return "到期通知 · 投资已完成结算"
   case .stockBought:
    return "交易回执 · 已买入 \(event.stockSymbol ?? "--") \(event.stockShares ?? 0) 股"
   case .stockSold:
    return "交易回执 · 已卖出 \(event.stockSymbol ?? "--") \(event.stockShares ?? 0) 股"
   case .stockHalted: return "停牌公告 · \(event.stockSymbol ?? "--") 暂停交易"
   case .passedGo: return "经过起点 · 通行奖金已入账"
   case .extraRoll: return "双骰好运 · 额外回合已获准"
   case .turnEnded: return "轮次更替 · 下一位玩家入场"
   case .cardDrawn:
    if event.deck == .chance { return "机会来函 · 阅后继续" }
    if event.deck == .chest { return "命运来函 · 阅后继续" }
    return "一封来函 · 阅后继续"
   case .jailed: return "法庭通知 · 请查看出狱方式"
   case .diceRolled:
    return "骰声已定 · 正在结算落点"
   default: continue
   }
  }
  return nil
 }

 /// Contextual notices use committed post-reducer state, not optimistic
 /// projected transactions. Missing/surprising effects fall back to the
 /// original universal UI copy. Never affects deterministic GameState.
 public static func contextualSummary(_ effects: [Effect], state: GameState) -> String? {
  guard let selected = effects.reversed().first(where: { summary([$0]) != nil ||
       [.auctionStarted, .bid, .bidFold, .tradeProposed].contains($0.kind) })
  else { return nil }
  func actorName(_ id: Int?) -> String? {
   guard let id, state.players.indices.contains(id) else { return nil }
   return state.players[id].name
  }
  func tileName(_ id: Int?) -> String? {
   guard let id, state.board.indices.contains(id) else { return nil }
   return state.board[id].name
  }
  let player = actorName(selected.player)
  let location = tileName(selected.tile)
  switch selected.kind {
  case .bought:
   if let location, let player, let amount = selected.amount, amount >= 0 {
    return "地契入册 · \(player) 以 ¥\(amount) 登记「\(location)」"
   }
  case .auctionStarted:
   if let location { return "公开竞价 · 「\(location)」已进入拍卖程序" }
  case .bid:
   if let player, let amount = selected.amount, amount > 0 {
    return "竞价举牌 · \(player) 报价 ¥\(amount)"
   }
  case .bidFold:
   if let player { return "竞价撤牌 · \(player) 已退出本轮竞价" }
  case .auctionWon:
   if let location, let player, let amount = selected.amount, amount >= 0 {
    return "拍卖落槌 · \(player) 以 ¥\(amount) 获得「\(location)」"
   }
  case .built:
   if let location, let tileID = selected.tile, state.board.indices.contains(tileID) {
    let t = state.board[tileID]
    let structure = t.hotel ? "旅馆" : "第\(t.houses)栋房屋"
    return "工务回执 · 「\(location)」已登记\(structure)"
   }
  case .mortgaged:
   if let location { return "抵押契据 · 「\(location)」暂停收租" }
  case .redeemed:
   if let location { return "赎回契据 · 「\(location)」恢复收租" }
  case .rentPaid:
   if let location, let amount = selected.amount, amount >= 0 {
    if let debt = state.pendingDebt, debt.player == selected.player {
     return "租约待清偿 · 「\(location)」仍有 ¥\(debt.amount) 待结算"
    }
    return "租约收据 · 「\(location)」租金 ¥\(amount) 已结算"
   }
  case .tradeProposed:
   if let from = player, let to = actorName(selected.to) {
    return "契约草案 · \(from) 已向 \(to) 发出交易提案"
   }
  case .stockBought:
   if let player, let symbol = selected.stockSymbol,
      let shares = selected.stockShares, let delta = selected.amount, delta < 0 {
    return "证券成交回执 · \(player) 买入 \(symbol) ×\(shares)，现金支出 ¥\(-delta)"
   }
  case .stockSold:
   if let player, let symbol = selected.stockSymbol,
      let shares = selected.stockShares, let delta = selected.amount, delta > 0 {
    return "证券成交回执 · \(player) 卖出 \(symbol) ×\(shares)，现金到账 ¥\(delta)"
   }
  case .gameWon:
   if let winner = actorName(state.winner) {
    return "终局公报 · \(winner) 成为本局胜者"
   }
  default: break
  }
  return summary(effects)
 }

}
