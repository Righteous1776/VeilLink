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
  case .financeOverdue: return "贷款已逾期，请先还款再存款、借款、买股或投资"
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

 /// How to recover from a rejected operation. The Engine error remains the
 /// authoritative reason; guidance never precommits a move or changes balances.
 public static func advice(_ error: GameError) -> String {
  switch error {
  case .noCash: return "请核对当前现金。可以先查看合法的抵押、卖房或银行操作，系统不会因本提示自动变卖财产。"
  case .notOwner: return "在地产管理中切换到自己名下的地块。仅查看其他人的地契不会赋予操作权限。"
  case .invalidTile: return "重新选择有效的街区、铁路或公共事业。特殊地块不能当成普通地产操作。"
  case .setNotComplete: return "先取得同色组全部街区，并检查组内是否存在抵押。"
  case .buildUneven: return "同色地块应优先建设等级较低者；卖房时应从等级最高者开始。"
  case .alreadyMortgaged: return "此项操作与抵押状态冲突。检查是否先要赎回，或先清除同色组建筑。"
  case .alreadyOwned: return "该产权已登记所有者，不能再次按无主地块价格购买。"
  case .insufficientBankSupply: return "银行可用房屋或旅馆不足，当前建设或降级无法完成。"
  case .invalidBid: return "竞价必须高于现有最高价，且不得超过当前玩家可用现金。"
  case .tradeMismatch: return "对方资产、现金或交易席位可能已经变化；请重新核对合同两方条件。"
  case .financeTermsPending: return "相关金融条款尚未完成规则裁决；此研发版本不会编造收益或期限。"
  case .financePositionLocked: return "该存款或投资尚未达到约定期数。请在账本中查看到期时间。"
  case .financeOverdue: return "请先偿还到期贷款，或通过合法取款、出售模拟股票筹资。逾期期间不能继续新增投资、存款与借款；系统不会额外收取未约定罚息。"
  case .stockTradingHalted: return "标的处于模拟停牌阶段，等待行情恢复后再考虑提交订单。"
  case .insufficientShares: return "卖出数量不得超过当前真实持仓数量。"
  case .stockNotFound: return "请重新选择五只现有的虚构股票之一。"
  case .wrongPhase: return "本回合尚未进入该操作阶段。等待当前结算完成，再在对应面板操作。"
  case .notYourTurn: return "当前行动权属于其他席位。不要在结算动画中重复点击提交。"
  case .gameFinished: return "对局已经进入终局，可以查看结算公报或明确重新开局。"
  case .noJailCard: return "当前没有可使用的机会／命运出狱卡；可按既定规则尝试其他出狱方式。"
  case .inJail: return "当前仍处于监狱状态，先完成合法的出狱步骤。"
  case .alreadyBankrupt: return "该席位已在当前局淘汰，后续操作需要由未破产玩家进行。"
  case .noDebt: return "当前并无待确认的清算债务，不需要提交破产动作。"
  case .invalidPayload: return "请核对金额、股数、期数、地块编号与所选产品是否符合当前规则。"
  case .invalidSequence: return "操作序号已过期。界面应重新读取当前状态，请勿反复发送旧订单。"
  case .invalidContext: return "当前阶段已变化。等待最新回合状态显示后再决定下一步。"
  case .invalidState: return "检测到无法继续的状态。请保留本地存档及诊断信息，避免直接清除应用数据。"
  }
 }

}
