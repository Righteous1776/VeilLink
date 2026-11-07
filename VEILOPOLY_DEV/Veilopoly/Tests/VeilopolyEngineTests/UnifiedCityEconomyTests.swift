import Foundation
import XCTest
@testable import VeilopolyEngine

final class UnifiedCityEconomyTests: XCTestCase {
 private func commit(_ g: inout GameState, _ type: MoveKind, amount: Int? = nil,
                     to: Int? = nil, tile: Int? = nil,
                     product: FinancialFeature? = nil,
                     periods: Int? = nil) throws -> [Effect] {
  let move = Move(type, player: g.turn.player, seq: g.nextSeq, tile: tile,
                  amount: amount, to: to, financeProduct: product, financePeriods: periods)
  let (next, effects) = try VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move).get()
  g = next; return effects
 }
 private func supply(_ g: GameState) -> Int {
  g.players.reduce(0) { $0 + $1.cash } + (g.banking?.reserveCash ?? 0)
 }

 func testV4OpeningCurrencyAndLegacyLedgerSeparation() throws {
  let city = VeilopolyCityLongEconomy.makeV4(seed: 98101)
  XCTAssertEqual(city.banking?.reserveCash, 160_000)
  XCTAssertEqual(supply(city), 188_800)
  XCTAssertEqual(city.banking?.financeRuleVersion, 4)
  XCTAssertEqual(city.cards, VeilopolyCityLongCards.allV4)
  XCTAssertEqual(city.cards.count, 32)
  let old = GameFactory.make(seed: 98101)
  XCTAssertNil(old.banking)
  XCTAssertEqual(old.players[0].cash, 1500)
  var v3 = city
  v3.banking?.financeRuleVersion = 3
  v3.banking?.reserveCash = nil
  v3.banking?.queuedClaims = nil
  v3.cards = VeilopolyCityLongCards.all
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let text = String(decoding: try encoder.encode(v3), as: UTF8.self)
  XCTAssertFalse(text.contains("reserveCash"), "Past V3 snapshots must retain old JSON ABI")
  XCTAssertTrue(IntegratedBanking.validate(try XCTUnwrap(v3.banking)))
 }

 func testPurchasesTaxesGoAndLoansUseOneFinitePool() throws {
  var city = VeilopolyCityLongEconomy.makeV4(seed: 98102)
  let supplyStart = supply(city)
  city.players[0].position = 1
  city.turn.phase = .tileResolve
  _ = try commit(&city, .resolveTile)
  let before = city.banking!.reserveCash!
  let p = VeilopolyCityLongEconomy.marketPressure(city)
  _ = try commit(&city, .buyProperty, tile: 1)
  XCTAssertEqual(city.players[0].cash, 7020)
  XCTAssertEqual(city.banking?.reserveCash, before + 180)
  XCTAssertNotEqual(VeilopolyCityLongEconomy.marketPressure(city), p,
                    "Building/property spending must visibly change the macro signal")
  XCTAssertEqual(supply(city), supplyStart)

  city.players[0].position = 4; city.turn.phase = .tileResolve
  _ = try commit(&city, .resolveTile)
  XCTAssertEqual(city.banking?.reserveCash, before + 180 + 600)
  XCTAssertEqual(supply(city), supplyStart)

  city.players[0].position = 38; city.turn.phase = .moveAnim
  city.turn.pendingSteps = 4
  _ = try commit(&city, .applyMovement)
  XCTAssertEqual(city.banking?.reserveCash, before + 180 + 600 - 1100)
  XCTAssertEqual(supply(city), supplyStart)

  city.turn.phase = .manage
  let pool = try XCTUnwrap(city.banking?.reserveCash)
  _ = try commit(&city, .bankBorrow, amount: 1000, periods: 4)
  XCTAssertEqual(city.banking?.reserveCash, pool - 1000)
  XCTAssertEqual(supply(city), supplyStart)
 }

 func testImmediateGiftsConserveSupplyAndRejectBadRecipients() throws {
  var game = VeilopolyCityLongEconomy.makeV4(seed: 98103)
  game.turn.phase = .manage
  let cash = game.players.map(\.cash), pool = game.banking!.reserveCash!
  let fx = try commit(&game, .transferCash, amount: 650, to: 2)
  XCTAssertEqual(game.players[0].cash, cash[0] - 650)
  XCTAssertEqual(game.players[2].cash, cash[2] + 650)
  XCTAssertEqual(game.banking?.reserveCash, pool)
  XCTAssertEqual(supply(game), VeilopolyCityLongEconomy.totalMoneySupply)
  XCTAssertTrue(fx.contains { $0.kind == .cashChanged && $0.to == 2 && $0.amount == -650 })
  let seq = game.nextSeq, hash = StateDigest.hash(game)
  for invalid in [-1,0,4,Int.max] {
   let candidate = Move(.transferCash, player: 0, seq: seq, amount: 100, to: invalid)
   guard case .failure(.invalidPayload) = VeilopolyEngine.apply(
    game, VeilopolyEngine.context(game), candidate) else {
    return XCTFail("Invalid recipient must not be paid")
   }
  }
  XCTAssertEqual(StateDigest.hash(game), hash)
  let overdraw = Move(.transferCash, player: 0, seq: seq, amount: 99999, to: 1)
  guard case .failure(.noCash) = VeilopolyEngine.apply(
   game, VeilopolyEngine.context(game), overdraw) else {
   return XCTFail("Insufficient sender cash cannot mint")
  }
 }

 func testFreeHouseCardConsumesRealHouseSupplyNotTreasury() throws {
  var game = VeilopolyCityLongEconomy.makeV4(seed: 98104)
  game.board[1].owner = 0; game.board[3].owner = 0
  game.players[0].position = 7; game.turn.phase = .tileResolve
  game.chanceDeck = DeckState(order: [13])
  let bankBefore = game.banking!.reserveCash!
  let inventory = game.bank.houses
  let fx = try commit(&game, .resolveTile)
  XCTAssertEqual(game.board[1].houses, 1)
  XCTAssertEqual(game.board[3].houses, 0)
  XCTAssertEqual(game.bank.houses, inventory - 1)
  XCTAssertEqual(game.players[0].cash, 7200)
  XCTAssertEqual(game.banking?.reserveCash, bankBefore)
  XCTAssertEqual(supply(game), VeilopolyCityLongEconomy.totalMoneySupply)
  XCTAssertTrue(fx.contains { $0.kind == .built && $0.tile == 1 && $0.amount == 0 })
 }

 func testNoEligibleHousePaysPrintedFallbackFromCentralBank() throws {
  var city = VeilopolyCityLongEconomy.makeV4(seed: 98105)
  city.players[0].position = 7; city.turn.phase = .tileResolve
  city.chanceDeck = DeckState(order: [13])
  let bankBefore = city.banking!.reserveCash!
  let fx = try commit(&city, .resolveTile)
  XCTAssertEqual(city.players[0].cash, 8000)
  XCTAssertEqual(city.banking?.reserveCash, bankBefore - 800)
  XCTAssertTrue(fx.contains { $0.text == "freeHouseFallback" && $0.amount == 800 })
  XCTAssertEqual(supply(city), VeilopolyCityLongEconomy.totalMoneySupply)
 }

 func testTreasuryFailureIsAtomicForDiscretionaryLoanAndSaveHash() throws {
  var city = VeilopolyCityLongEconomy.makeV4(seed: 98106)
  // Give the existing currency to players; the shared supply remains intact.
  city.players[0].cash += 159_500
  city.banking?.reserveCash = 500
  city.turn.phase = .manage
  let before = StateDigest.hash(city)
  let attempt = Move(.bankBorrow, player: 0, seq: city.nextSeq, amount: 1000, financePeriods: 3)
  guard case .failure(.bankLiquidity) = VeilopolyEngine.apply(
   city, VeilopolyEngine.context(city), attempt) else {
   return XCTFail("Bank cannot issue money beyond its remaining liquid reserve")
  }
  XCTAssertEqual(StateDigest.hash(city), before)
 }

 func testTamperedMoneySupplyRejectedBeforeActionAndRoundTrip() throws {
  var city = VeilopolyCityLongEconomy.makeV4(seed: 98107)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let restored = try JSONDecoder().decode(GameState.self, from: encoder.encode(city))
  XCTAssertEqual(restored, city)
  XCTAssertEqual(StateDigest.hash(restored), StateDigest.hash(city))
  city.players[0].cash += 1
  guard case .failure(.invalidState) = VeilopolyEngine.apply(
   city, VeilopolyEngine.context(city), Move(.rollDice, player: 0, seq: 0)) else {
   return XCTFail("Tampered cash is incompatible with immutable supply")
  }
 }

 func testStockOrdersAndDepositsExchangeCashWithCentralBank() throws {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 98109)
  g.turn.phase = .manage
  let supplyStart = supply(g)
  let reserveStart = try XCTUnwrap(g.banking?.reserveCash)
  let buy = Move(.stockBuy, player: 0, seq: g.nextSeq, stockSymbol: "VTL", stockShares: 2)
  let bought = try VeilopolyEngine.apply(g, VeilopolyEngine.context(g), buy).get()
  g = bought.0
  XCTAssertTrue(bought.1.contains { $0.kind == .stockBought })
  XCTAssertEqual(g.banking?.reserveCash, reserveStart + 297)
  XCTAssertEqual(supply(g), supplyStart)
  let sell = Move(.stockSell, player: 0, seq: g.nextSeq, stockSymbol: "VTL", stockShares: 1)
  let sold = try VeilopolyEngine.apply(g, VeilopolyEngine.context(g), sell).get()
  g = sold.0
  XCTAssertTrue(sold.1.contains { $0.kind == .stockSold })
  XCTAssertEqual(g.banking?.reserveCash, reserveStart + 297 - 147)
  XCTAssertEqual(supply(g), supplyStart)
  let beforeSaving = try XCTUnwrap(g.banking?.reserveCash)
  _ = try commit(&g, .bankDeposit, amount: 1000, product: .demandDeposit)
  XCTAssertEqual(g.banking?.reserveCash, beforeSaving + 1000)
  XCTAssertEqual(supply(g), supplyStart)
 }

 func testSameTransferAndPriceTicksReplayToIdenticalAuthoritativeHashes() throws {
  func trajectory() throws -> GameState {
   var g = VeilopolyCityLongEconomy.makeV4(seed: 98110)
   g.turn.phase = .manage
   _ = try commit(&g, .transferCash, amount: 250, to: 1)
   _ = try commit(&g, .bankBorrow, amount: 500, periods: 3)
   _ = try commit(&g, .stockTick)
   return g
  }
  let a = try trajectory(), b = try trajectory()
  XCTAssertEqual(a, b)
  XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
  XCTAssertEqual(supply(a), VeilopolyCityLongEconomy.totalMoneySupply)
 }

 func testMarketPressureMakesIdenticallySeededTapeRespondToCommerce() throws {
  let base = VeilopolyCityLongEconomy.makeV4(seed: 98108)
  XCTAssertEqual(VeilopolyCityLongEconomy.marketPressure(base), 0)
  var tick0 = try XCTUnwrap(base.banking?.market)
  var tickA = tick0
  var tickB = tick0
  _ = try StockMarketEngine.advance(&tickA, economicPressure: 90)
  _ = try StockMarketEngine.advance(&tickB, economicPressure: -90)
  XCTAssertNotEqual(tickA.quotes.map(\.currentPriceCents),
                    tickB.quotes.map(\.currentPriceCents))
  _ = try StockMarketEngine.advance(&tick0, economicPressure: 0)
  let oldMarket = StockMarketEngine.initial(seed: 98108)
  var oldA = oldMarket, oldB = oldMarket
  _ = try StockMarketEngine.advance(&oldA)
  _ = try StockMarketEngine.advance(&oldB, economicPressure: 900)
  XCTAssertEqual(oldA, oldB, "V2 tape must ignore the new economic signal")
 }
}
