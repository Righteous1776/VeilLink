import Foundation

public enum VeilopolyEngine {
 public typealias Transition = Result<(GameState, [Effect]), GameError>

 public static func context(_ g: GameState) -> GameContext {
  let choices: [MoveKind]
  switch g.turn.phase {
  case .roll: choices = [.rollDice, .payBail, .useJailCard]
  case .moveAnim: choices = [.applyMovement]
  case .tileResolve: choices = g.turn.pendingPurchase == nil ? [.resolveTile] : [.buyProperty, .startAuction]
  case .auction: choices = [.bid]
  case .manage: choices = [.buildHouse, .sellHouse, .mortgage, .redeem, .proposeTrade, .endTurn,
                           .bankDeposit, .bankWithdraw, .bankBorrow, .bankRepay, .bankInvest, .bankSettle,
                           .stockBuy, .stockSell, .stockTick]
  case .trade: choices = [.counterTrade, .acceptTrade, .rejectTrade]
  case .debt: choices = [.declareBankruptcy]
  case .finished: choices = []
  }
  return GameContext(currentPlayer: g.turn.player, phase: g.turn.phase,
                     allowedMoves: choices, lastRoll: g.turn.lastRoll)
 }

 /// No mutation escapes a failed move. All arithmetic is integral. No wall clock or ambient RNG.
 public static func apply(_ state: GameState, _ ctx: GameContext, _ move: Move) -> Transition {
  var g = state
  var effects: [Effect] = []
  do {
   guard g.board.count == 40, g.players.count == 4,
         g.players.enumerated().allSatisfy({ $0.offset == $0.element.id }),
         g.players.allSatisfy({ (0...1_000_000_000).contains($0.cash) && (0..<40).contains($0.position) }),
         g.board.allSatisfy({ t in
          (0...1_000_000).contains(t.price) && (0...4).contains(t.houses) &&
          (t.kind != .street || t.rent.count == 6) &&
          (t.owner == nil || (0..<4).contains(t.owner!))
         }),
         g.cards.allSatisfy({ card in card.effects.allSatisfy({ e in
          (e.amount == nil || (-1_000_000...1_000_000).contains(e.amount!)) &&
          (e.perHouse == nil || (0...1_000_000).contains(e.perHouse!)) &&
          (e.perHotel == nil || (0...1_000_000).contains(e.perHotel!))
         }) }) else { throw GameError.invalidState }
   guard (g.banking.map { IntegratedBanking.validate($0) } ?? true) else { throw GameError.invalidState }
   guard ctx == context(g) else { throw GameError.invalidContext }
   guard g.winner == nil else { throw GameError.gameFinished }
   guard move.seq == g.nextSeq else { throw GameError.invalidSequence }
   guard (0..<g.players.count).contains(move.player) else { throw GameError.invalidPayload }
   guard !g.players[move.player].bankrupt else { throw GameError.alreadyBankrupt }
   let expected: Int
   if g.turn.phase == .auction { expected = g.auction?.turn ?? -1 }
   else if g.turn.phase == .trade { expected = g.trade?.to ?? -1 }
   else if g.turn.phase == .debt { expected = g.pendingDebt?.player ?? -1 }
   else { expected = g.turn.player }
   guard move.player == expected else { throw GameError.notYourTurn }
   guard ctx.allowedMoves.contains(move.type) else { throw GameError.wrongPhase }
   try transition(&g, move, &effects)
   // Validate the output as well as the input. A large legal receipt must not
   // produce an out-of-range persisted state that crashes the next turn.
   guard g.players.allSatisfy({ (0...1_000_000_000).contains($0.cash) }),
         (g.banking.map { IntegratedBanking.validate($0) } ?? true),
         (0...32).contains(g.bank.houses) && (0...12).contains(g.bank.hotels) else {
    throw GameError.invalidState
   }
   g.moveLog.append(move)
   g.nextSeq += 1
   return .success((g, effects))
  } catch let error as GameError { return .failure(error) }
  catch { return .failure(.invalidState) }
 }

 private static func transition(_ g: inout GameState, _ m: Move, _ fx: inout [Effect]) throws {
  let p = m.player
  switch m.type {
  case .rollDice:
   let d1 = Int(seededRNG(seed: g.seed, counter: &g.rngCounter) % 6) + 1
   let d2 = Int(seededRNG(seed: g.seed, counter: &g.rngCounter) % 6) + 1
   let same = d1 == d2
   g.turn.lastRoll = [d1,d2]; g.turn.rollCount += 1
   g.turn.pendingSteps = d1 + d2
   g.turn.rolledDouble = same
   g.turn.releasedFromJail = false
   fx.append(Effect(.diceRolled, player: p, dice: [d1,d2]))
   if g.players[p].jailTurns > 0 {
    if same {
     g.players[p].jailTurns = 0; g.turn.releasedFromJail = true
     g.turn.rolledDouble = false; g.turn.doubleCount = 0
     fx.append(Effect(.released, player: p))
    } else {
     g.players[p].jailTurns -= 1
     if g.players[p].jailTurns == 0 {
      try charge(&g, debtor: p, amount: 50, creditor: nil, &fx)
      if g.pendingDebt != nil { return }
      fx.append(Effect(.released, player: p, amount: -50))
     } else {
      g.turn.phase = .manage; g.turn.rolledDouble = false
      return
     }
    }
   } else if same {
    g.turn.doubleCount += 1
    if g.turn.doubleCount >= 3 { jail(&g, p, &fx); return }
   } else { g.turn.doubleCount = 0 }
   g.turn.phase = .moveAnim
  case .applyMovement:
   guard (2...12).contains(g.turn.pendingSteps) else { throw GameError.invalidState }
   let n = g.turn.pendingSteps
   let from = g.players[p].position
   let to = (from + n) % 40
   if from + n >= 40 { g.players[p].cash += 200; fx.append(Effect(.passedGo, player: p, amount: 200)) }
   g.players[p].position = to
   g.turn.pendingSteps = 0
   fx.append(Effect(.playerMoved, player: p, from: from, to: to, steps: n))
   g.turn.phase = .tileResolve
  case .resolveTile:
   try resolveLanding(&g, player: p, rentMultiplier: 1, depth: 0, &fx)
  case .buyProperty:
   guard let tile = g.turn.pendingPurchase, m.tile == tile else { throw GameError.invalidTile }
   guard g.board[tile].owner == nil else { throw GameError.alreadyOwned }
   let price = g.board[tile].price
   guard g.players[p].cash >= price else { throw GameError.noCash }
   g.players[p].cash -= price; g.board[tile].owner = p
   g.turn.pendingPurchase = nil; g.turn.phase = .manage
   fx.append(Effect(.bought, player: p, tile: tile, amount: price))
  case .startAuction:
   guard let tile = g.turn.pendingPurchase, m.tile == tile else { throw GameError.invalidTile }
   let active = g.players.filter { !$0.bankrupt }.map(\.id)
   guard active.count > 1 else { throw GameError.invalidState }
   g.auction = AuctionState(tile: tile, active: active)
   g.turn.pendingPurchase = nil; g.turn.phase = .auction
   fx.append(Effect(.auctionStarted, player: p, tile: tile))
  case .bid:
   guard var auction = g.auction, auction.turn == p else { throw GameError.invalidState }
   let index = auction.active.firstIndex(of: p)
   guard let index = index else { throw GameError.invalidState }
   if let amount = m.amount, amount > 0 {
    guard amount >= 1, amount > auction.currentBid, amount <= g.players[p].cash else { throw GameError.invalidBid }
    auction.currentBid = amount; auction.bidder = p
    fx.append(Effect(.bid, player: p, tile: auction.tile, amount: amount))
    if auction.active.count > 1 { auction.turn = auction.active[(index + 1) % auction.active.count] }
   } else {
    auction.active.remove(at: index)
    fx.append(Effect(.bidFold, player: p, tile: auction.tile))
    if !auction.active.isEmpty { auction.turn = auction.active[index % auction.active.count] }
   }
   if auction.active.count <= 1 {
    if let buyer = auction.bidder, auction.active.contains(buyer) {
     guard g.players[buyer].cash >= auction.currentBid else { throw GameError.noCash }
     g.players[buyer].cash -= auction.currentBid; g.board[auction.tile].owner = buyer
     fx.append(Effect(.auctionWon, player: buyer, tile: auction.tile, amount: auction.currentBid))
    }
    g.auction = nil; g.turn.phase = .manage
   } else { g.auction = auction }
  case .buildHouse:
   guard let i = m.tile, isTile(i, in: g), g.board[i].kind == .street else { throw GameError.invalidTile }
   let t = g.board[i]
   guard t.owner == p else { throw GameError.notOwner }
   guard !t.mortgaged else { throw GameError.alreadyMortgaged }
   guard let color = t.color else { throw GameError.invalidState }
   let group = groupIndices(g, color)
   guard group.allSatisfy({ g.board[$0].owner == p }) else { throw GameError.setNotComplete }
   guard group.allSatisfy({ !g.board[$0].mortgaged }) else { throw GameError.alreadyMortgaged }
   let levels = group.map { buildingLevel(g.board[$0]) }
   let targetLevel = buildingLevel(t)
   guard targetLevel < 5, targetLevel == (levels.min() ?? 0) else { throw GameError.buildUneven }
   guard g.players[p].cash >= t.houseCost else { throw GameError.noCash }
   if targetLevel < 4 {
    guard g.bank.houses > 0 else { throw GameError.insufficientBankSupply }
    g.bank.houses -= 1; g.board[i].houses += 1
   } else {
    guard g.bank.hotels > 0 else { throw GameError.insufficientBankSupply }
    g.bank.hotels -= 1; g.bank.houses += 4; g.board[i].houses = 0; g.board[i].hotel = true
   }
   g.players[p].cash -= t.houseCost
   fx.append(Effect(.built, player: p, tile: i, amount: t.houseCost))
  case .sellHouse:
   guard let i = m.tile, isTile(i, in: g), g.board[i].kind == .street else { throw GameError.invalidTile }
   guard g.board[i].owner == p else { throw GameError.notOwner }
   try sellOneBuilding(&g, tile: i, &fx)
  case .mortgage:
   guard let i = m.tile, isTile(i, in: g), g.board[i].purchasable else { throw GameError.invalidTile }
   guard g.board[i].owner == p else { throw GameError.notOwner }
   guard !g.board[i].mortgaged else { throw GameError.alreadyMortgaged }
   guard mayMortgage(g, i) else { throw GameError.invalidPayload }
   mortgageOne(&g, tile: i, &fx)
  case .redeem:
   guard let i = m.tile, isTile(i, in: g), g.board[i].purchasable else { throw GameError.invalidTile }
   guard g.board[i].owner == p else { throw GameError.notOwner }
   guard g.board[i].mortgaged else { throw GameError.invalidPayload }
   let principal = g.board[i].price / 2
   let fee = principal + (principal + 9) / 10 // round-up 10% of mortgage value
   guard g.players[p].cash >= fee else { throw GameError.noCash }
   g.players[p].cash -= fee; g.board[i].mortgaged = false
   fx.append(Effect(.redeemed, player: p, tile: i, amount: fee))
  case .proposeTrade:
   guard let to = m.to, to != p, (0..<4).contains(to), !g.players[to].bankrupt,
         let offer = m.offer, let request = m.request else { throw GameError.invalidPayload }
   guard validTransfer(offer, from: p, g: g), validTransfer(request, from: to, g: g) else { throw GameError.tradeMismatch }
   g.trade = TradeState(from: p, to: to, offer: offer, request: request)
   g.turn.phase = .trade
   fx.append(Effect(.tradeProposed, player: p, to: to))
  case .counterTrade:
   guard let old = g.trade, old.to == p, let offer = m.offer, let request = m.request else { throw GameError.tradeMismatch }
   guard validTransfer(offer, from: p, g: g), validTransfer(request, from: old.from, g: g) else { throw GameError.tradeMismatch }
   g.trade = TradeState(from: p, to: old.from, offer: offer, request: request)
   fx.append(Effect(.tradeProposed, player: p, to: old.from))
  case .acceptTrade:
   guard let t = g.trade, t.to == p else { throw GameError.tradeMismatch }
   guard validTransfer(t.offer, from: t.from, g: g), validTransfer(t.request, from: t.to, g: g) else { throw GameError.tradeMismatch }
   g.players[t.from].cash += t.request.cash - t.offer.cash
   g.players[t.to].cash += t.offer.cash - t.request.cash
   g.players[t.from].chanceJailCards += t.request.chanceCards - t.offer.chanceCards
   g.players[t.from].chestJailCards += t.request.chestCards - t.offer.chestCards
   g.players[t.to].chanceJailCards += t.offer.chanceCards - t.request.chanceCards
   g.players[t.to].chestJailCards += t.offer.chestCards - t.request.chestCards
   for i in t.offer.tiles { g.board[i].owner = t.to }
   for i in t.request.tiles { g.board[i].owner = t.from }
   g.turn.phase = .manage; g.trade = nil
   fx.append(Effect(.traded, player: t.from, to: t.to))
  case .rejectTrade:
   guard g.trade != nil else { throw GameError.tradeMismatch }
   g.trade = nil; g.turn.phase = .manage
   fx.append(Effect(.tradeRejected, player: p))
  case .payBail:
   guard g.players[p].jailTurns > 0 else { throw GameError.inJail }
   guard g.players[p].cash >= 50 else { throw GameError.noCash }
   g.players[p].cash -= 50; g.players[p].jailTurns = 0
   fx.append(Effect(.released, player: p, amount: -50))
  case .useJailCard:
   guard g.players[p].jailTurns > 0 else { throw GameError.inJail }
   let useDeck: DeckKind
   if let deck = m.deck { useDeck = deck }
   else { useDeck = g.players[p].chanceJailCards > 0 ? .chance : .chest }
   if useDeck == .chance {
    guard g.players[p].chanceJailCards > 0 else { throw GameError.noJailCard }
    g.players[p].chanceJailCards -= 1
   } else {
    guard g.players[p].chestJailCards > 0 else { throw GameError.noJailCard }
    g.players[p].chestJailCards -= 1
   }
   g.players[p].jailTurns = 0
   fx.append(Effect(.released, player: p, deck: useDeck))
  case .declareBankruptcy:
   guard let debt = g.pendingDebt, debt.player == p else { throw GameError.noDebt }
   try bankrupt(&g, debtor: p, creditor: debt.creditor, &fx)
   g.pendingDebt = nil
  case .bankDeposit, .bankWithdraw, .bankBorrow, .bankRepay, .bankInvest, .bankSettle,
       .stockBuy, .stockSell, .stockTick:
   try IntegratedBanking.apply(&g, move: m, effects: &fx)
  case .endTurn:
   g.pendingCard = nil
   let previous = g.turn.player
   if g.turn.rolledDouble, g.players[previous].jailTurns == 0 {
    g.turn.phase = .roll
    g.turn.pendingPurchase = nil
    fx.append(Effect(.extraRoll, player: previous))
   } else {
    let active = (1...4).map { (previous + $0) % 4 }.first { !g.players[$0].bankrupt }
    guard let next = active else { throw GameError.invalidState }
    g.turn = TurnState(); g.turn.player = next
    fx.append(Effect(.turnEnded, player: previous, to: next))
    IntegratedBanking.advanceTurn(&g, effects: &fx)
   }
  }
 }

 private static func isTile(_ tile: Int, in g: GameState) -> Bool { (0..<g.board.count).contains(tile) }
 private static func groupIndices(_ g: GameState, _ color: ColorGroup) -> [Int] {
  g.board.filter { $0.color == color && $0.kind == .street }.map(\.i)
 }
 private static func buildingLevel(_ tile: Tile) -> Int { tile.hotel ? 5 : tile.houses }
 private static func ownsColorGroup(_ g: GameState, _ i: Int) -> Bool {
  guard let color = g.board[i].color, let owner = g.board[i].owner else { return false }
  return groupIndices(g,color).allSatisfy { g.board[$0].owner == owner }
 }
 private static func mayMortgage(_ g: GameState, _ i: Int) -> Bool {
  let t = g.board[i]
  guard t.purchasable, t.owner != nil, !t.mortgaged else { return false }
  if let color = t.color { return groupIndices(g,color).allSatisfy { !g.board[$0].improved } }
  return true
 }
 private static func mortgageOne(_ g: inout GameState, tile i: Int, _ fx: inout [Effect]) {
  let p = g.board[i].owner!
  let amount = g.board[i].price / 2
  g.players[p].cash += amount; g.board[i].mortgaged = true
  fx.append(Effect(.mortgaged, player: p, tile: i, amount: amount))
 }
 private static func sellOneBuilding(_ g: inout GameState, tile i: Int, _ fx: inout [Effect]) throws {
  let t = g.board[i]
  guard let color = t.color, t.improved else { throw GameError.invalidPayload }
  let levels = groupIndices(g,color).map { buildingLevel(g.board[$0]) }
  guard buildingLevel(t) == levels.max() else { throw GameError.buildUneven }
  if t.hotel {
   guard g.bank.houses >= 4 else { throw GameError.insufficientBankSupply }
   g.bank.hotels += 1; g.bank.houses -= 4
   g.board[i].hotel = false; g.board[i].houses = 4
  } else {
   g.bank.houses += 1; g.board[i].houses -= 1
  }
  let value = t.houseCost / 2
  g.players[t.owner!].cash += value
  fx.append(Effect(.soldBuilding, player: t.owner, tile: i, amount: value))
 }
 private static func rent(_ g: GameState, i: Int, dice: Int, multiplier: Int) -> Int {
  let t = g.board[i]
  guard let owner = t.owner, !t.mortgaged else { return 0 }
  switch t.kind {
  case .street:
   let level = buildingLevel(t)
   return t.rent[level] * (level == 0 && ownsColorGroup(g, i) ? 2 : 1) * multiplier
  case .railroad:
   let count = g.board.filter { $0.kind == .railroad && $0.owner == owner }.count
   return 25 * (1 << (count - 1)) * multiplier
  case .utility:
   let count = g.board.filter { $0.kind == .utility && $0.owner == owner }.count
   return dice * (count == 2 ? 10 : 4) * multiplier
  default: return 0
  }
 }
 private static func resolveLanding(_ g: inout GameState, player p: Int, rentMultiplier: Int,
                                    depth: Int, _ fx: inout [Effect]) throws {
  guard depth < 9 else { throw GameError.invalidState }
  let i = g.players[p].position
  let tile = g.board[i]
  g.turn.pendingPurchase = nil
  switch tile.kind {
  case .street, .railroad, .utility:
   if tile.owner == nil { g.turn.pendingPurchase = i; g.turn.phase = .tileResolve }
   else if tile.owner != p && !tile.mortgaged {
    let fee = rent(g, i: i, dice: g.turn.lastRoll.reduce(0,+), multiplier: rentMultiplier)
    try charge(&g, debtor: p, amount: fee, creditor: tile.owner, &fx)
    fx.append(Effect(.rentPaid, player: p, tile: i, to: tile.owner, amount: fee))
    if g.pendingDebt == nil { g.turn.phase = .manage }
   } else { g.turn.phase = .manage }
  case .tax:
   try charge(&g, debtor: p, amount: i == 4 ? 200 : 100, creditor: nil, &fx)
   if g.pendingDebt == nil { g.turn.phase = .manage }
  case .chance, .chest:
   let deck: DeckKind = tile.kind == .chance ? .chance : .chest
   var d = deck == .chance ? g.chanceDeck : g.chestDeck
   guard !d.order.isEmpty else { throw GameError.invalidState }
   let id = d.order[d.cursor % d.order.count]; d.cursor += 1
   if deck == .chance { g.chanceDeck = d } else { g.chestDeck = d }
   guard let card = g.cards.first(where: { $0.id == id && $0.deck == deck }) else { throw GameError.invalidState }
   g.pendingCard = PendingCard(id: id, deck: deck)
   fx.append(Effect(.cardDrawn, player: p, tile: i, amount: id, text: card.text, deck: deck))
   g.turn.phase = .manage
   try applyCard(card, to: p, state: &g, depth: depth+1, &fx)
  case .goToJail:
   jail(&g, p, &fx)
  default: g.turn.phase = .manage
  }
 }
 private static func jail(_ g: inout GameState, _ p: Int, _ fx: inout [Effect]) {
  g.players[p].position = 10; g.players[p].jailTurns = 3
  g.turn.pendingSteps = 0; g.turn.pendingPurchase = nil
  g.turn.rolledDouble = false; g.turn.doubleCount = 0
  g.turn.phase = .manage
  fx.append(Effect(.jailed, player: p, tile: 10))
 }
 private static func applyCard(_ card: CardDefinition, to p: Int, state g: inout GameState,
                               depth: Int, _ fx: inout [Effect]) throws {
  for effect in card.effects {
   if g.pendingDebt != nil { break }
   switch effect.kind {
   case .cash:
    guard let amount = effect.amount, let target = effect.target else { throw GameError.invalidState }
    if target == .allOthers {
     for other in g.players.indices where other != p && !g.players[other].bankrupt {
      if amount >= 0 { try charge(&g, debtor: other, amount: amount, creditor: p, &fx) }
      else { try charge(&g, debtor: p, amount: -amount, creditor: other, &fx) }
      if g.pendingDebt != nil { break }
     }
    } else if amount >= 0 {
     g.players[p].cash += amount
     fx.append(Effect(.cashChanged, player: p, amount: amount))
    } else { try charge(&g, debtor: p, amount: -amount, creditor: nil, &fx) }
   case .moveTo:
    guard let dest = effect.tile, (0..<40).contains(dest) else { throw GameError.invalidState }
    let from = g.players[p].position
    if effect.collectGo == true && dest < from || (effect.collectGo == true && dest == 0) {
     g.players[p].cash += 200; fx.append(Effect(.passedGo, player: p, amount: 200))
    }
    g.players[p].position = dest
    fx.append(Effect(.playerMoved, player: p, from: from, to: dest, steps: 0))
    try resolveLanding(&g, player: p, rentMultiplier: 1, depth: depth, &fx)
   case .moveNearest:
    guard let nearest = effect.nearest else { throw GameError.invalidState }
    let kind: TileKind = nearest == .railroad ? .railroad : .utility
    let from = g.players[p].position
    guard let step = (1...40).first(where: { g.board[(from + $0) % 40].kind == kind }) else { throw GameError.invalidState }
    let dest = (from + step) % 40
    if from + step >= 40 { g.players[p].cash += 200; fx.append(Effect(.passedGo, player: p, amount: 200)) }
    g.players[p].position = dest
    fx.append(Effect(.playerMoved, player: p, from: from, to: dest, steps: step))
    try resolveLanding(&g, player: p, rentMultiplier: max(1, effect.multiplier ?? 1), depth: depth, &fx)
   case .moveRelative:
    guard let delta = effect.delta, (-39...39).contains(delta) else { throw GameError.invalidState }
    let from = g.players[p].position; let dest = (from + delta + 40) % 40
    if delta > 0 && from + delta >= 40 { g.players[p].cash += 200; fx.append(Effect(.passedGo, player: p, amount: 200)) }
    g.players[p].position = dest
    fx.append(Effect(.playerMoved, player: p, from: from, to: dest, steps: delta))
    try resolveLanding(&g, player: p, rentMultiplier: 1, depth: depth, &fx)
   case .goToJail: jail(&g, p, &fx)
   case .jailCard:
    if card.deck == .chance { g.players[p].chanceJailCards += 1 }
    else { g.players[p].chestJailCards += 1 }
   case .repair:
    guard let perHouse = effect.perHouse, let perHotel = effect.perHotel else { throw GameError.invalidState }
    let owned = g.board.filter { $0.owner == p }
    let cost = owned.reduce(0) { $0 + $1.houses * perHouse + ($1.hotel ? perHotel : 0) }
    try charge(&g, debtor: p, amount: cost, creditor: nil, &fx)
   }
  }
 }

 /// Automatic fixed-order liquidation; a residual debt remains explicit for declareBankruptcy.
 private static func charge(_ g: inout GameState, debtor p: Int, amount: Int, creditor: Int?,
                            _ fx: inout [Effect]) throws {
  guard amount >= 0 else { throw GameError.invalidPayload }
  if amount == 0 { return }
  if g.players[p].cash < amount {
   IntegratedBanking.releaseAvailableSavingsForDebt(&g, debtor: p, amount: amount, effects: &fx)
   // 1. Mortgage every unimproved eligible lot, index order.
   for i in g.board.indices where g.players[p].cash < amount {
    if g.board[i].owner == p && mayMortgage(g, i) { mortgageOne(&g, tile: i, &fx) }
   }
   // 2. Sell buildings evenly; after the last building, freed land can be mortgaged.
   while g.players[p].cash < amount {
    var progress = false
    for i in g.board.indices where g.players[p].cash < amount {
     if g.board[i].owner == p && g.board[i].improved &&
        (try? sellOneBuilding(&g, tile: i, &fx)) != nil { progress = true }
    }
    for i in g.board.indices where g.players[p].cash < amount {
     if g.board[i].owner == p && mayMortgage(g, i) { mortgageOne(&g, tile: i, &fx); progress = true }
    }
    if !progress { break }
   }
   fx.append(Effect(.liquidation, player: p, amount: amount))
  }
  if g.players[p].cash >= amount {
   g.players[p].cash -= amount
   if let receiver = creditor, !g.players[receiver].bankrupt { g.players[receiver].cash += amount }
   fx.append(Effect(.cashChanged, player: p, to: creditor, amount: -amount))
  } else {
   g.pendingDebt = PendingDebt(player: p, amount: amount, creditor: creditor)
   g.turn.phase = .debt
  }
 }
 private static func bankrupt(_ g: inout GameState, debtor p: Int, creditor: Int?, _ fx: inout [Effect]) throws {
  try IntegratedBanking.closeBankruptAccount(&g, player: p, effects: &fx)
  let receiver = creditor.flatMap { id in (0..<g.players.count).contains(id) && id != p && !g.players[id].bankrupt ? id : nil }
  if let receiver = receiver {
   g.players[receiver].cash += g.players[p].cash
   g.players[receiver].chanceJailCards += g.players[p].chanceJailCards
   g.players[receiver].chestJailCards += g.players[p].chestJailCards
  }
  for i in g.board.indices where g.board[i].owner == p {
   if receiver == nil {
    if g.board[i].hotel { g.bank.hotels += 1 }
    else { g.bank.houses += g.board[i].houses }
    g.board[i].owner = nil; g.board[i].mortgaged = false
    g.board[i].houses = 0; g.board[i].hotel = false
   } else { g.board[i].owner = receiver }
  }
  g.players[p].cash = 0; g.players[p].chanceJailCards = 0
  g.players[p].chestJailCards = 0; g.players[p].bankrupt = true
  fx.append(Effect(.bankrupt, player: p, to: receiver))
  let survivors = g.players.filter { !$0.bankrupt }.map(\.id)
  if survivors.count == 1 {
   g.winner = survivors[0]; g.turn.phase = .finished
   fx.append(Effect(.gameWon, player: survivors[0]))
  } else if g.turn.player != p && !g.players[g.turn.player].bankrupt {
   // An allOthers card can bankrupt a nonactive player; resume the card drawer's turn.
   g.turn.phase = .manage
  } else {
   g.turn = TurnState()
   g.turn.player = survivors.first(where: { $0 > p }) ?? survivors[0]
  }
 }
 private static func validTransfer(_ t: TradeTransfer, from p: Int, g: GameState) -> Bool {
  guard t.cash >= 0, t.cash <= g.players[p].cash,
        t.chanceCards >= 0, t.chanceCards <= g.players[p].chanceJailCards,
        t.chestCards >= 0, t.chestCards <= g.players[p].chestJailCards,
        Set(t.tiles).count == t.tiles.count else { return false }
  return t.tiles.allSatisfy { i in
   guard isTile(i,in:g), g.board[i].owner == p else { return false }
   if let color = g.board[i].color {
    return groupIndices(g,color).allSatisfy { !g.board[$0].improved }
   }
   return true
  }
 }
}
