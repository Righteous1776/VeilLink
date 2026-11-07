import VeilopolyEngine

public enum VeilopolyManagementSection: String, CaseIterable, Identifiable {
 case property = "地产", bank = "银行", market = "股市", trade = "交易"
 public var id: String { rawValue }
 public var symbol: String {
  switch self {
  case .property: return "house"
  case .bank: return "building.columns"
  case .market: return "chart.xyaxis.line"
  case .trade: return "arrow.left.arrow.right"
  }
 }
}

/// Shared presentation projections. Book assets do not alter the engine's
/// winner, liquidity rules, pending product terms or historical sandbox rules.
public struct VeilopolyAssetSummary: Equatable {
 public let cash: Int
 public let property: Int
 public let savings: Int
 public let investments: Int
 public let stocks: Int
 public let liabilities: Int
 public var netWorth: Int { cash + property + savings + investments + stocks - liabilities }
 public init(game: GameState, player: Int) {
  let account = game.banking.flatMap { $0.accounts.indices.contains(player) ? $0.accounts[player] : nil }
  cash = game.players.indices.contains(player) ? game.players[player].cash : 0
  property = game.board.filter { $0.owner == player }.reduce(0) {
   $0 + ($1.mortgaged ? $1.price / 2 : $1.price) + $1.houses * $1.houseCost + ($1.hotel ? 5 * $1.houseCost : 0)
  }
  savings = account?.savings.reduce(0) { $0 + $1.principal } ?? 0
  investments = account?.positions.reduce(0) { $0 + $1.principal } ?? 0
  stocks = game.banking?.market.map { StockMarketEngine.portfolioMarketValueCents($0, player: player) / 100 } ?? 0
  liabilities = account?.loans.reduce(0) { $0 + $1.totalDue } ?? 0
 }
}

public enum VeilopolyGamePresentation {
 public static func counterOffer(_ trade: TradeState, offeredCash: Int, requestedCash: Int,
                                 sequence: Int) -> Move {
  var offer = trade.request
  var request = trade.offer
  offer.cash = offeredCash
  request.cash = requestedCash
  return Move(.counterTrade, player: trade.to, seq: sequence, offer: offer, request: request)
 }

 public static func requiresDecision(_ phase: Phase) -> Bool {
  [.tileResolve, .auction, .trade, .debt, .finished].contains(phase)
 }

 /// Preview the actual pure reducer rather than implementing a second set of
 /// property/build/finance rules in the UI. Does not commit moves or RNG state.
 public static func rejection(_ game: GameState, move: Move) -> String? {
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move) {
  case .success: return nil
  case .failure(let error): return message(error)
  }
 }

 public static func message(_ error: GameError) -> String {
  switch error {
  case .noCash: return "可用现金不足"
  case .notOwner: return "请选择自己持有的地产"
  case .invalidTile: return "该地块不支持此操作"
  case .setNotComplete: return "集齐同色地产后才能建造"
  case .buildUneven: return "同色地产需均衡建造或出售"
  case .alreadyMortgaged: return "请先处理地产抵押状态"
  case .alreadyOwned: return "地产已有持有人"
  case .insufficientBankSupply: return "银行房屋或酒店库存不足"
  case .invalidBid: return "出价需高于当前竞价且不超过现金"
  case .tradeMismatch: return "交易条件已变化，请重新选择"
  case .financeTermsPending: return "该金融条件尚未开放"
  case .financePositionLocked: return "尚未到可取回或结算的期数"
  case .stockTradingHalted: return "股票暂停交易，请等待恢复"
  case .insufficientShares: return "持股数量不足"
  case .stockNotFound: return "股票不存在"
  case .wrongPhase, .notYourTurn: return "请等待当前行动完成"
  case .gameFinished: return "本局已结束"
  case .noJailCard: return "没有可用的出狱卡"
  case .inJail: return "请先完成出狱操作"
  case .alreadyBankrupt: return "该玩家已破产"
  case .noDebt: return "当前没有待处理债务"
  case .invalidPayload: return "请检查金额、期数与所选资产"
  case .invalidSequence, .invalidContext, .invalidState: return "当前状态无法执行此操作，请稍后重试"
  }
 }
}
