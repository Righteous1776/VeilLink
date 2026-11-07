import Foundation

/// Read-only automation of real bank due dates; no wager or invented rates.
public struct VeilopolyBankNotice: Equatable, Identifiable {
 public let id: String
 public let text: String
 public let urgent: Bool
 public init(_ id: String, _ text: String, urgent: Bool) {
  self.id=id; self.text=text; self.urgent=urgent
 }
}
public struct VeilopolyBankDigest: Equatable {
 public let period: Int
 public let notices: [VeilopolyBankNotice]
 public let memorandum: String
}
public enum VeilopolyBankAutomation {
 public static func digest(_ game: GameState, player: Int) -> VeilopolyBankDigest? {
  guard game.players.indices.contains(player) else { return nil }
  guard let ledger=game.banking, ledger.accounts.indices.contains(player) else {
   return .init(period:0,notices:[],
    memorandum:"银号账本尚未启用，完成首笔有效金融操作后开始自动记录。")
  }
  let now=ledger.completedTurns
  let a=ledger.accounts[player]
  var notes: [VeilopolyBankNotice]=[]
  for s in a.savings {
   let remaining=max(0,s.unlockPeriod-now)
   if remaining<=2 {
    notes.append(.init("saving-\(s.id)",
      remaining==0 ? "存款 #\(s.id) 已达可取回期 · 本金 ¥\(s.principal)"
                   : "存款 #\(s.id) 距可取回还有 \(remaining) 期",
      urgent:remaining==0))
   }
  }
  for loan in a.loans {
   let remaining=max(0,loan.duePeriod-now)
   let overdue=max(0,now-loan.duePeriod)
   if remaining<=2 {
    let description: String
    if overdue>0 {
     description="贷款 #\(loan.id) 已逾期 \(overdue) 期 · 尚欠 ¥\(loan.totalDue)"
    } else if remaining==0 {
     description="贷款 #\(loan.id) 已到期 · 待偿 ¥\(loan.totalDue)"
    } else {
     description="贷款 #\(loan.id) 距到期还有 \(remaining) 期 · 待偿 ¥\(loan.totalDue)"
    }
    notes.append(.init("loan-\(loan.id)",description,urgent:remaining==0))
   }
  }
  for item in a.positions {
   let remaining=max(0,item.duePeriod-now)
   if remaining<=2 {
    let ready=ledger.terms.payouts[item.feature]?.count == 6
    notes.append(.init("investment-\(item.id)",
      remaining>0 ? "投资 #\(item.id) 距到期还有 \(remaining) 期"
      : (ready ? "投资 #\(item.id) 已到期，等待玩家确认结算"
               : "投资 #\(item.id) 已达约定期数，但收益条款尚未批准"),
      urgent:remaining==0))
   }
  }
  notes.sort {
   if $0.urgent != $1.urgent { return $0.urgent }
   return $0.id < $1.id
  }
  let memos = [
   "柜台札记 · 金融期数随普通回合推进；额外掷骰不提前到期。",
   "柜台札记 · 银行本金、可用现金与虚构证券持仓分开记录。",
   ledger.financeRuleVersion == 2
    ? "柜台札记 · V2 贷款现金充足时按期自动偿还；其他结算仍需合法操作。"
    : "柜台札记 · 旧对局保留原有手动还款规则；其他结算仍需合法操作。",
   "柜台札记 · 固定收益必须来自已批准条款，不能随机承诺。"
  ]
  var counter: UInt64=0
  let memoSeed=game.seed ^ (UInt64(now) &* 0x9E3779B97F4A7C15) ^ 0x5645_494C_4241_4E4B
  let pick=Int(seededRNG(seed:memoSeed,counter:&counter)%UInt64(memos.count))
  return .init(period:now,notices:notes,memorandum:memos[pick])
 }
}
