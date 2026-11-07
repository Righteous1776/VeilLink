import VeilopolyEngine

/// Text-only fallback cues. Kimi may replace their presentation with animated
/// skins, but the reducer remains the authoritative source for every message.
public enum VeilopolyEventFeedback {
 public static func summary(_ effects: [Effect]) -> String? {
  for event in effects.reversed() {
   switch event.kind {
   case .gameWon: return "本局结束 · 胜者已经产生"
   case .bankrupt: return "一名玩家已破产，资产清算完成"
   case .auctionWon: return "竞拍成交 · 地产归属已更新"
   case .bought: return "购买成功 · 地产已登记"
   case .built: return "建造完成 · 租金等级提高"
   case .soldBuilding: return "建筑已售回银行 · 现金已到账"
   case .mortgaged: return "地产已抵押 · 抵押期间暂停收租"
   case .redeemed: return "地产已赎回 · 恢复正常收租"
   case .traded: return "交易完成 · 现金与地产归属已更新"
   case .tradeRejected: return "本次交易未达成"
   case .rentPaid: return "租金已支付 · 双方现金已结算"
   case .bankBorrowed: return "贷款申请成功 · 请留意到期日"
   case .bankRepaid: return "贷款已偿还"
   case .bankDeposited: return "存款已转入银行账本"
   case .bankWithdrawn: return "存款取回成功"
   case .bankInvestmentOpened: return "模拟投资已开启"
   case .bankInvestmentSettled: return "投资到期 · 结算已完成"
   case .stockBought:
    return "股票买入成交 · \(event.stockSymbol ?? "--") \(event.stockShares ?? 0) 股"
   case .stockSold:
    return "股票卖出成交 · \(event.stockSymbol ?? "--") \(event.stockShares ?? 0) 股"
   case .stockHalted: return "行情触及涨跌幅限制 · \(event.stockSymbol ?? "--") 暂停交易"
   case .passedGo: return "经过起点 · 已结算奖励"
   case .extraRoll: return "掷出双骰 · 获得额外回合"
   case .turnEnded: return "下一位玩家开始行动"
   case .cardDrawn: return "抽到一张卡片 · 阅读后继续"
   case .jailed: return "进入监狱 · 请选择出狱方式"
   case .diceRolled:
    return "骰子已落定 · 正在结算移动"
   default: continue
   }
  }
  return nil
 }
}
