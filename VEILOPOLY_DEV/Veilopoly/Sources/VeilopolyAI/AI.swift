import VeilopolyEngine

public struct AIProfile: Equatable {
 public var reserveCash: Int
 public var buyPercent: Int
 public var maxBidPercent: Int
 public var tradingEnabled: Bool
 public static func forLevel(_ level: AILevel) -> Self {
  switch level {
  case .conservative: return .init(reserveCash: 450, buyPercent: 65, maxBidPercent: 65, tradingEnabled: false)
  case .balanced: return .init(reserveCash: 250, buyPercent: 90, maxBidPercent: 85, tradingEnabled: false)
  case .aggressive: return .init(reserveCash: 100, buyPercent: 115, maxBidPercent: 110, tradingEnabled: true)
  }
 }
}

/// Deterministic, integer-only decision policy. The 400–900 ms presentation delay is deliberately outside AI.
public enum VeilopolyAI {
 public static func decide(_ g: GameState, _ ctx: GameContext, me: Int, level: AILevel) -> Move {
  let profile = AIProfile.forLevel(level)
  let p = g.players[me]
  let seq = g.nextSeq
  func m(_ kind: MoveKind, tile: Int? = nil, amount: Int? = nil) -> Move {
   Move(kind, player: me, seq: seq, tile: tile, amount: amount)
  }
  switch ctx.phase {
  case .roll:
   if p.jailTurns > 0 {
    if p.chanceJailCards > 0 { return Move(.useJailCard, player: me, seq: seq, deck: .chance) }
    if p.chestJailCards > 0 { return Move(.useJailCard, player: me, seq: seq, deck: .chest) }
    if p.cash > profile.reserveCash + 50 && p.jailTurns == 1 { return m(.payBail) }
   }
   return m(.rollDice)
  case .moveAnim: return m(.applyMovement)
  case .tileResolve:
   guard let i = g.turn.pendingPurchase else { return m(.resolveTile) }
   let property = g.board[i]
   let valuation = estimate(g, i, me, level)
   if p.cash - property.price >= profile.reserveCash && valuation * 100 >= property.price * profile.buyPercent {
    return m(.buyProperty, tile: i)
   }
   return m(.startAuction, tile: i)
  case .auction:
   guard let auction = g.auction else { return m(.bid) }
   let valuation = estimate(g, auction.tile, me, level) * profile.maxBidPercent / 100
   let nextBid = auction.currentBid == 0 ? 1 : auction.currentBid + max(1, auction.currentBid / 10)
   if nextBid <= valuation && nextBid <= p.cash - profile.reserveCash {
    return m(.bid, amount: nextBid)
   }
   return m(.bid, amount: 0)
  case .manage:
   // Pure adjudication of due liabilities and mature savings/investments.
   if let bankMove = FinancialRuleJudge.recommendation(g, player: me) { return bankMove }
   // Build only on an even-development minimum, and never in a mortgaged group.
   let owned = g.board.filter { $0.kind == .street && $0.owner == me && !$0.mortgaged }
   for tile in owned {
    guard let color = tile.color else { continue }
    let group = g.board.filter { $0.kind == .street && $0.color == color }
    guard group.allSatisfy({ $0.owner == me && !$0.mortgaged }) else { continue }
    let level = tile.hotel ? 5 : tile.houses
    let low = group.map { $0.hotel ? 5 : $0.houses }.min() ?? 0
    if level == low && level < 5 && p.cash - tile.houseCost >= profile.reserveCash &&
       (level == 4 ? g.bank.hotels > 0 : g.bank.houses > 0) {
     return m(.buildHouse, tile: tile.i)
    }
   }
   if profile.tradingEnabled &&
      !g.moveLog.suffix(25).contains(where: { $0.player == me && $0.type == .proposeTrade }) {
    for tile in owned {
     guard let color = tile.color else { continue }
     let group = g.board.filter { $0.color == color }
     let mine = group.filter { $0.owner == me }.count
     if mine >= group.count - 1,
        let wanted = group.first(where: { $0.owner != nil && $0.owner != me && !$0.improved }),
        let other = wanted.owner {
      let offerPrice = wanted.price * 5 / 4
      if p.cash - offerPrice >= profile.reserveCash {
       return Move(.proposeTrade, player: me, seq: seq, to: other,
                   offer: TradeTransfer(cash: offerPrice), request: TradeTransfer(tiles: [wanted.i]))
      }
     }
    }
   }
   return m(.endTurn)
  case .trade:
   guard let trade = g.trade else { return m(.rejectTrade) }
   // Receiver's utility is measured by the same integer valuation function; no RNG.
   let incoming = trade.offer.cash + trade.offer.tiles.reduce(0) { $0 + estimate(g, $1, me, level) }
   let outgoing = trade.request.cash + trade.request.tiles.reduce(0) { $0 + estimate(g, $1, me, level) }
   let incomingCards = trade.offer.chanceCards + trade.offer.chestCards
   let outgoingCards = trade.request.chanceCards + trade.request.chestCards
   if incoming + 50 * incomingCards >= outgoing + 50 * outgoingCards &&
      trade.request.cash <= p.cash {
    return m(.acceptTrade)
   }
   return m(.rejectTrade)
  case .debt: return m(.declareBankruptcy)
  case .finished: return m(.endTurn)
  }
 }

 private static func estimate(_ g: GameState, _ i: Int, _ me: Int, _ level: AILevel) -> Int {
  let t = g.board[i]
  var value = t.price
  if let color = t.color {
   let group = g.board.filter { $0.color == color }
   let owned = group.filter { $0.owner == me }.count
   if owned > 0 { value += 60 * owned }
   if owned == group.count - 1 { value += t.price / 2 }
  }
  if t.kind == .railroad { value += 25 * g.board.filter { $0.kind == .railroad && $0.owner == me }.count }
  if t.kind == .utility { value += 20 * g.board.filter { $0.kind == .utility && $0.owner == me }.count }
  if level == .conservative { value = value * 80 / 100 }
  if level == .aggressive { value = value * 120 / 100 }
  return value
 }
}

public enum LocalLoopError: Error { case engine(GameError), turnLimit }
public struct AutoGameStats: Equatable {
 public var totalMoves: Int
 public var completed: Bool
 public var winner: Int?
 public var finalHash: String
}
public enum LocalGameRunner {
 /// No SpriteKit or real-time waiting; drives internal moves and AI through the same public apply() entry.
 public static func autoplay(seed: UInt64, maxMoves: Int = 4_000,
                             levels: [AILevel] = [.balanced,.balanced,.aggressive,.conservative]) throws -> AutoGameStats {
  var g = GameFactory.make(seed: seed, humanCount: 0, levels: levels)
  while g.winner == nil && g.nextSeq < maxMoves {
   let ctx = VeilopolyEngine.context(g)
   let actor = g.auction?.turn ?? g.trade?.to ?? g.pendingDebt?.player ?? g.turn.player
   let m = decideForRunner(g, ctx, actor)
   switch VeilopolyEngine.apply(g, ctx, m) {
   case .success((let next, _)): g = next
   case .failure(let err): throw LocalLoopError.engine(err)
   }
  }
  return AutoGameStats(totalMoves: g.nextSeq, completed: g.winner != nil,
                       winner: g.winner, finalHash: StateDigest.hash(g))
 }
 private static func decideForRunner(_ g: GameState, _ ctx: GameContext, _ actor: Int) -> Move {
  VeilopolyAI.decide(g, ctx, me: actor, level: g.players[actor].aiLevel)
 }
}
