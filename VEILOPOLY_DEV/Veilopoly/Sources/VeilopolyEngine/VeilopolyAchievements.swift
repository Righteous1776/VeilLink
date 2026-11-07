/// Read-only, deterministic milestones derived from the canonical game state.
/// No additional save schema, rewards, currency or network authority.
public struct VeilopolyAchievement: Equatable, Identifiable {
 public let id: String
 public let title: String
 public let detail: String
 public let progress: Int
 public let requirement: Int
 /// Historical entries derive from the committed move log. Other entries
 /// are CURRENT portfolio targets, so they may lock again after a trade.
 public let historical: Bool
 public var unlocked: Bool { progress >= requirement }
 public var displayedProgress: Int { min(progress, requirement) }
}

public enum VeilopolyAchievements {
 /// Pure public-information projection: no mutation, RNG, storage or time.
 public static func entries(in game: GameState, player seat: Int) -> [VeilopolyAchievement] {
  guard game.players.indices.contains(seat) else { return [] }
  var actions: [MoveKind: Int] = [:]
  var positiveBids = 0
  for move in game.moveLog where move.player == seat {
   actions[move.type, default: 0] += 1
   if move.type == .bid && (move.amount ?? 0) > 0 { positiveBids += 1 }
  }
  func count(_ kind: MoveKind) -> Int { actions[kind, default: 0] }
  let owned = game.board.filter { $0.purchasable && $0.owner == seat }.count
  let fullDistricts = ColorGroup.allCases.filter { group in
   let streets = game.board.filter { $0.kind == .street && $0.color == group }
   return !streets.isEmpty && streets.allSatisfy { $0.owner == seat }
  }.count
  let hotels = game.board.filter { $0.owner == seat && $0.hotel }.count
  func entry(_ id: String, _ title: String, _ detail: String,
             _ progress: Int, _ requirement: Int = 1,
             historical: Bool = true) -> VeilopolyAchievement {
   VeilopolyAchievement(id: id, title: title, detail: detail,
                        progress: progress, requirement: requirement, historical: historical)
  }
  return [
   entry("first-roll", "起点的第一声", "完成第一次掷骰", count(.rollDice)),
   entry("ten-rolls", "跨过十个晨昏", "累计完成十次掷骰", count(.rollDice), 10),
   entry("first-deed", "第一纸地契", "完成首次购地", count(.buyProperty)),
   entry("three-assets", "城市收藏家", "当前持有至少三处可购买地产", owned, 3, historical: false),
   entry("color-set", "街区之钥", "当前完整持有一个颜色街区", fullDistricts, historical: false),
   entry("first-building", "施工的灯火", "完成第一次房屋建造", count(.buildHouse)),
   entry("five-buildings", "天际线设计师", "累计完成五次房屋建造", count(.buildHouse), 5),
   entry("hotel", "灯火通明", "当前拥有至少一座酒店", hotels, historical: false),
   entry("auction", "第一次举牌", "完成一次有效竞价", positiveBids),
   entry("trade", "桌上的契约", "成功接受一次玩家交易", count(.acceptTrade)),
   entry("redeem", "重获地契", "完成一次抵押赎回", count(.redeem)),
   entry("deposit", "储蓄的起点", "完成一次游戏银行存款", count(.bankDeposit)),
   entry("repayment", "归还承诺", "完成一次游戏银行还款", count(.bankRepay)),
   entry("market-entry", "行情观察者", "完成一次虚构股票买入", count(.stockBuy)),
   entry("market-exit", "完成买卖", "完成一次虚构股票卖出", count(.stockSell)),
   entry("victory", "城市终章", "成为本局获胜玩家", game.winner == seat ? 1 : 0)
  ]
 }
}
