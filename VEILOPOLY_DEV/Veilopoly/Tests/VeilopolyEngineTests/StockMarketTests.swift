import XCTest
@testable import VeilopolyEngine

final class StockMarketTests: XCTestCase {
 private func step(_ game: inout GameState, _ kind: MoveKind,
                   symbol: String? = nil, shares: Int? = nil) throws -> [Effect] {
  let move = Move(kind, player: game.turn.player, seq: game.nextSeq,
                  stockSymbol: symbol, stockShares: shares)
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move) {
  case .success((let next, let effects)): game = next; return effects
  case .failure(let error): throw error
  }
 }

 func testInitialMarketContainsFiveFictionalInstrumentsAndValidTape() {
  let market = StockMarketEngine.initial(seed: 42)
  XCTAssertTrue(StockMarketEngine.validate(market))
  XCTAssertEqual(market.quotes.map(\.symbol), ["VTL", "AUR", "MNT", "NOV", "ORB"])
  XCTAssertEqual(market.portfolios.count, 4)
  XCTAssertTrue(market.quotes.allSatisfy { $0.history.count == 1 && $0.sessionVolume == 0 })
 }

 func testSameSeedProducesIdenticalReasonableLongRun() throws {
  var a = StockMarketEngine.initial(seed: 8_241)
  var b = StockMarketEngine.initial(seed: 8_241)
  let original = a.quotes.map(\.currentPriceCents)
  for _ in 0..<2_000 {
   XCTAssertEqual(try StockMarketEngine.advance(&a), try StockMarketEngine.advance(&b))
   XCTAssertEqual(a, b)
   XCTAssertTrue(StockMarketEngine.validate(a))
   for quote in a.quotes {
    XCTAssertGreaterThanOrEqual(quote.currentPriceCents, quote.sessionOpenCents * 90 / 100)
    XCTAssertLessThanOrEqual(quote.currentPriceCents, quote.sessionOpenCents * 110 / 100)
   }
  }
  XCTAssertEqual(a.quotes.map(\.history.count), Array(repeating: StockMarketEngine.maximumHistoryPoints, count: 5))
  XCTAssertNotEqual(a.quotes.map(\.currentPriceCents), original)
 }

 func testDifferentSeedsDivergeWithoutTouchingDiceRNG() throws {
  var a = Fixture.game(.manage)
  var b = a; b.seed += 1
  let diceCounter = a.rngCounter
  _ = try step(&a, .stockTick)
  _ = try step(&b, .stockTick)
  XCTAssertEqual(a.rngCounter, diceCounter)
  XCTAssertEqual(b.rngCounter, diceCounter)
  XCTAssertNotEqual(a.banking?.market?.quotes.map(\.currentPriceCents),
                    b.banking?.market?.quotes.map(\.currentPriceCents))
 }

 func testBuySellAverageCostFeesAndRealizedPnL() throws {
  var market = StockMarketEngine.initial(seed: 77)
  var cash = 1_500
  let buyPreview = try StockMarketEngine.estimateBuy(market, player: 0, symbol: "VTL", shares: 10)
  XCTAssertEqual(buyPreview, StockTradeEstimate(symbol: "VTL", shares: 10,
                                                priceCents: 1_850, grossCash: 185,
                                                fee: 1, cashDelta: -186))
  let buy = try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 10, cash: &cash)
  XCTAssertEqual(buy.priceCents, 1_850)
  XCTAssertEqual(buy.fee, 1)
  XCTAssertEqual(cash, 1_314)
  XCTAssertEqual(market.portfolios[0].position(symbol: "VTL"),
                 StockPosition(symbol: "VTL", shares: 10, averageCostCents: 1_860))
  let sell = try StockMarketEngine.sell(&market, player: 0, symbol: "VTL", shares: 4, cash: &cash)
  XCTAssertEqual(sell.cashDelta, 73)
  XCTAssertEqual(sell.realizedPnLCents, -140)
  XCTAssertEqual(cash, 1_387)
  XCTAssertEqual(market.portfolios[0].position(symbol: "VTL")?.shares, 6)
  XCTAssertEqual(market.portfolios[0].feesPaid, 2)
 }

 func testMaximumBuyableSharesUsesExactFeesAndPositionCapacity() throws {
  var market = StockMarketEngine.initial(seed: 80)
  XCTAssertEqual(StockMarketEngine.maximumBuyableShares(
   market, player: 0, symbol: "VTL", cash: 186), 10)
  XCTAssertEqual(StockMarketEngine.maximumBuyableShares(
   market, player: 0, symbol: "VTL", cash: 185), 9)
  XCTAssertEqual(StockMarketEngine.maximumBuyableShares(
   market, player: 0, symbol: "REAL", cash: 10_000), 0)
  var cash = 1_000_000
  _ = try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 10_000, cash: &cash)
  market.portfolios[0].positions[0].shares = 99_995
  XCTAssertEqual(StockMarketEngine.maximumBuyableShares(
   market, player: 0, symbol: "VTL", cash: cash), 5)
 }

 func testHighPriceSingleShareIncludesPercentageFeeInValidCostBasis() throws {
  var market = StockMarketEngine.initial(seed: 78)
  market.quotes[0].basePriceCents = 1_000_000
  market.quotes[0].previousCloseCents = 1_000_000
  market.quotes[0].sessionOpenCents = 1_000_000
  market.quotes[0].currentPriceCents = 1_000_000
  market.quotes[0].highCents = 1_000_000
  market.quotes[0].lowCents = 1_000_000
  market.quotes[0].history[0].priceCents = 1_000_000
  var cash = 20_000
  let receipt = try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 1, cash: &cash)
  XCTAssertEqual(receipt.fee, 50)
  XCTAssertEqual(market.portfolios[0].position(symbol: "VTL")?.averageCostCents, 1_005_000)
  XCTAssertTrue(StockMarketEngine.validate(market))
 }

 func testDirectTradeFinalValidationFailureDoesNotPartiallyCommit() {
  var market = StockMarketEngine.initial(seed: 79)
  market.portfolios[0].feesPaid = 1_000_000_000
  let before = market
  var cash = 1_500
  XCTAssertThrowsError(try StockMarketEngine.buy(
   &market, player: 0, symbol: "VTL", shares: 1, cash: &cash
  )) {
   XCTAssertEqual($0 as? GameError, .invalidState)
  }
  XCTAssertEqual(market, before)
  XCTAssertEqual(cash, 1_500)
 }

 func testReducerRecordsStructuredTradeAndStockTick() throws {
  var game = Fixture.game(.manage)
  let buy = try step(&game, .stockBuy, symbol: "MNT", shares: 5)
  XCTAssertEqual(buy.first?.kind, .stockBought)
  XCTAssertEqual(buy.first?.stockSymbol, "MNT")
  XCTAssertEqual(buy.first?.stockShares, 5)
  XCTAssertEqual(game.moveLog.last?.type, .stockBuy)
  XCTAssertEqual(game.banking?.market?.portfolios[0].position(symbol: "MNT")?.shares, 5)
  let tick = try step(&game, .stockTick)
  XCTAssertTrue(tick.contains { $0.kind == .stockTicked })
  XCTAssertEqual(game.banking?.market?.tick, 1)
  XCTAssertEqual(game.nextSeq, 2)
 }

 func testInvalidOrdersAreAtomic() throws {
  var game = Fixture.game(.manage)
  let initial = StateDigest.hash(game)
  Fixture.fails(game, Move(.stockBuy, player: 0, seq: 0,
                           stockSymbol: "REAL", stockShares: 1), .stockNotFound)
  XCTAssertEqual(StateDigest.hash(game), initial)
  Fixture.fails(game, Move(.stockSell, player: 0, seq: 0,
                           stockSymbol: "VTL", stockShares: 1), .insufficientShares)
  XCTAssertEqual(StateDigest.hash(game), initial)
  game.players[0].cash = 1
  Fixture.fails(game, Move(.stockBuy, player: 0, seq: 0,
                           stockSymbol: "ORB", stockShares: 100), .noCash)
 }

 func testTradingHaltRejectsOrderUntilTapeAdvances() throws {
  var market = StockMarketEngine.initial(seed: 1)
  market.quotes[0].haltedTicks = 1
  var cash = 1_500
  XCTAssertThrowsError(try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 1, cash: &cash)) {
   XCTAssertEqual($0 as? GameError, .stockTradingHalted)
  }
  _ = try StockMarketEngine.advance(&market)
  XCTAssertEqual(market.quotes[0].haltedTicks, 0)
 }

 func testDebtCoverSellsLiquidStockBeforeProperty() throws {
  var game = Fixture.game(.manage)
  _ = try step(&game, .stockBuy, symbol: "MNT", shares: 20)
  game.players[0].cash = 0
  var effects: [Effect] = []
  IntegratedBanking.releaseAvailableSavingsForDebt(&game, debtor: 0, amount: 100, effects: &effects)
  XCTAssertGreaterThanOrEqual(game.players[0].cash, 100)
  XCTAssertTrue(effects.contains { $0.kind == .stockSold && $0.text == "automaticDebtCover" })
  XCTAssertLessThan(game.banking?.market?.portfolios[0].position(symbol: "MNT")?.shares ?? 0, 20)
 }

 func testLedgerWithoutMarketDecodesAndLazilyCreatesOne() throws {
  let old = IntegratedBankLedger(completedTurns: 9, market: nil)
  let data = try JSONEncoder().encode(old)
  let restored = try JSONDecoder().decode(IntegratedBankLedger.self, from: data)
  XCTAssertNil(restored.market)
  var game = Fixture.game(.manage); game.banking = restored
  _ = try step(&game, .stockTick)
  XCTAssertEqual(game.banking?.market?.tick, 1)
  XCTAssertEqual(game.banking?.completedTurns, 9)
 }
 func testNewMarketsUseIrregularButReplayableRNGVersion() throws {
  let baseline = StockMarketEngine.initial(seed: 21_260)
  XCTAssertEqual(baseline.algorithmVersion, 2)
  var a = baseline, b = baseline
  var changeTicks: [Int] = []
  for _ in 0..<450 {
   let oldRegime = a.regime
   XCTAssertEqual(try StockMarketEngine.advance(&a), try StockMarketEngine.advance(&b))
   XCTAssertEqual(a, b)
   XCTAssertTrue(StockMarketEngine.validate(a))
   if oldRegime != a.regime { changeTicks.append(a.tick) }
  }
  XCTAssertGreaterThan(changeTicks.count, 2)
  XCTAssertFalse(changeTicks.allSatisfy { $0 % 24 == 0 })
 }
 func testLegacyMarketDecodesWithoutVersionKeyAndKeepsExactRNG() throws {
  var old = StockMarketEngine.initial(seed: 6)
  old.algorithmVersion = 1
  let jsonEncoder = JSONEncoder()
  jsonEncoder.outputFormatting = [.sortedKeys]
  let before = try jsonEncoder.encode(old)
  let encoded = try XCTUnwrap(String(data: before, encoding: .utf8))
  XCTAssertFalse(encoded.contains("algorithmVersion"))
  let recovered = try JSONDecoder().decode(StockMarketState.self, from: before)
  XCTAssertEqual(recovered.algorithmVersion, 1)
  XCTAssertEqual(try jsonEncoder.encode(recovered), before)
  var expected = old, actual = recovered
  for _ in 0..<250 {
   XCTAssertEqual(try StockMarketEngine.advance(&expected), try StockMarketEngine.advance(&actual))
   XCTAssertEqual(expected, actual)
  }
 }
 func testDifferentNewGamesProduceDiverseButBoundedMarkets() throws {
  var closingTapes = Set<String>()
  for seed in 1...16 {
   var m = StockMarketEngine.initial(seed: UInt64(seed))
   for _ in 0..<80 { _ = try StockMarketEngine.advance(&m) }
   XCTAssertTrue(StockMarketEngine.validate(m))
   closingTapes.insert(m.quotes.map { String($0.currentPriceCents) }.joined(separator: ","))
  }
  XCTAssertEqual(closingTapes.count, 16)
 }
 func testVersionedMarketRNGDoesNotAdvanceDiceCounter() throws {
  var game = Fixture.game(.manage)
  let oldCounter = game.rngCounter
  _ = try step(&game, .stockTick)
  XCTAssertEqual(game.rngCounter, oldCounter)
  XCTAssertEqual(game.banking?.market?.algorithmVersion, 2)
 }

 func testMarketTickFailureLeavesQuoteAndRNGCompletelyUntouched() throws {
  var market = StockMarketEngine.initial(seed: 704)
  market.rngCounter = 100_000_000
  XCTAssertTrue(StockMarketEngine.validate(market))
  let before = market
  XCTAssertThrowsError(try StockMarketEngine.advance(&market)) {
   XCTAssertEqual($0 as? GameError, .invalidState)
  }
  XCTAssertEqual(market, before)
  // This is also a correct input rejection, not just a posttick rollback.
  market.tick = 1_000_000
  let limit = market
  XCTAssertThrowsError(try StockMarketEngine.advance(&market))
  XCTAssertEqual(market, limit)
 }
 func testValidTicksStillProduceIdenticalMarketOnReplay() throws {
  var a = StockMarketEngine.initial(seed: 705)
  var b = a
  for _ in 0..<350 {
   let aEvents = try StockMarketEngine.advance(&a)
   let bEvents = try StockMarketEngine.advance(&b)
   XCTAssertEqual(aEvents, bEvents)
   XCTAssertEqual(a, b)
  }
 }
}
