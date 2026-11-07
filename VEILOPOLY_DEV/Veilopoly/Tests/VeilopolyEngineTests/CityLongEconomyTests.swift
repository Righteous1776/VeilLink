import Foundation
import XCTest
@testable import VeilopolyEngine

final class CityLongEconomyTests: XCTestCase {
 private func apply(_ game: inout GameState, _ move: Move) throws -> [Effect] {
  let (next, effects) = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move).get()
  game = next
  return effects
 }
 func testNewMatchIsVersionedAndOldFactoryUntouched() {
  let old = GameFactory.make(seed: 7821, humanCount: 1)
  let city = VeilopolyCityLongEconomy.make(seed: 7821, humanCount: 1)
  XCTAssertEqual(old.players.map(\.cash), [1500,1500,1500,1500])
  XCTAssertNil(old.banking)
  XCTAssertEqual(old.board[1].price, 60)
  XCTAssertEqual(city.players.map(\.cash), [7200,7200,7200,7200])
  XCTAssertEqual(city.board[1].price, 180)
  XCTAssertEqual(city.board[1].rent[0], 4)
  XCTAssertEqual(city.board[1].houseCost, 150)
  XCTAssertEqual(city.board.count, old.board.count)
  XCTAssertEqual(city.chanceDeck, old.chanceDeck)
  XCTAssertEqual(city.chestDeck, old.chestDeck)
  XCTAssertEqual(city.rngCounter, old.rngCounter)
  XCTAssertEqual(city.banking?.financeRuleVersion, 3)
  XCTAssertEqual(city.banking?.terms.loanInterestBasisPoints, [800,1100,1400,1700])
  XCTAssertNotNil(city.banking)
  XCTAssertTrue(IntegratedBanking.validate(city.banking!))
 }
 func testPassingGoSalaryAndTaxChangeOnlyInLongSession() throws {
  var city = VeilopolyCityLongEconomy.make(seed: 7822)
  city.players[0].position = 38
  city.turn.phase = .moveAnim
  city.turn.pendingSteps = 4
  let start = city.players[0].cash
  let fx = try apply(&city, Move(.applyMovement, player: 0, seq: 0))
  XCTAssertEqual(city.players[0].cash, start + 1100)
  XCTAssertTrue(fx.contains { $0.kind == .passedGo && $0.amount == 1100 })
  city.players[0].position = 4
  city.turn.phase = .tileResolve
  let cash = city.players[0].cash
  _ = try apply(&city, Move(.resolveTile, player: 0, seq: city.nextSeq))
  XCTAssertEqual(city.players[0].cash, cash - 600)
  XCTAssertEqual(VeilopolyCityLongEconomy.bail(city), 150)
  XCTAssertEqual(VeilopolyCityLongEconomy.cardCash(city, amount: 100), 100)
  let old = GameFactory.make(seed: 7822)
  XCTAssertEqual(VeilopolyCityLongEconomy.salary(old), 200)
  XCTAssertEqual(VeilopolyCityLongEconomy.tax(old, tile: 4), 200)
 }
 func testDemandSavingsCannotCompoundInSamePeriod() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 7823)
  g.turn.phase = .manage
  let cash = g.players[0].cash
  _ = try apply(&g, Move(.bankDeposit, player: 0, seq: 0, amount: 1000,
                         financeProduct: .demandDeposit))
  let deposit = try XCTUnwrap(g.banking?.accounts[0].savings.first)
  XCTAssertEqual(deposit.unlockPeriod, 1)
  XCTAssertEqual(g.players[0].cash, cash - 1000)
  let result = VeilopolyEngine.apply(g, VeilopolyEngine.context(g),
    Move(.bankWithdraw, player: 0, seq: g.nextSeq, financeID: deposit.id))
  guard case .failure(.financePositionLocked) = result else {
   return XCTFail("Same-period withdrawal would enable unlimited profit")
  }
  _ = try apply(&g, Move(.endTurn, player: 0, seq: g.nextSeq))
  g.turn.player = 0; g.turn.phase = .manage
  _ = try apply(&g, Move(.bankWithdraw, player: 0, seq: g.nextSeq, financeID: deposit.id))
  XCTAssertEqual(g.players[0].cash, cash + 15)
 }
 func testFlatTermLoanDoesNotMultiplyByMonthsAndLegacyQuoteIsPreserved() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 7824)
  g.turn.phase = .manage
  _ = try apply(&g, Move(.bankBorrow, player: 0, seq: 0, amount: 1000, financePeriods: 6))
  let loan = try XCTUnwrap(g.banking?.accounts[0].loans.first)
  XCTAssertEqual(loan.totalDue, 1080)
  XCTAssertEqual(loan.duePeriod, 6)
  XCTAssertEqual(g.players[0].cash, 8200)
  var legacy = GameFactory.make(seed: 7824)
  legacy.turn.phase = .manage
  _ = try apply(&legacy, Move(.bankBorrow, player: 0, seq: 0, amount: 500, financePeriods: 3))
  XCTAssertEqual(legacy.banking?.accounts[0].loans.first?.totalDue, 800)
 }
 func testAtLeastFourEligibleLotsStillPermitLongSessionCredit() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 7825)
  for i in [1,3,5,6,8] { g.board[i].owner = 0 }
  g.turn.phase = .manage
  _ = try apply(&g, Move(.bankBorrow, player: 0, seq: 0, amount: 7000, financePeriods: 8))
  XCTAssertEqual(g.banking?.accounts[0].loans.first?.totalDue, 7560)
 }
 func testEnhancedStockOrdersAndDeterministicTickTape() throws {
  var city = StockMarketEngine.initial(seed: 7826, enhanced: true)
  let old = StockMarketEngine.initial(seed: 7826)
  XCTAssertEqual(city.algorithmVersion, 3)
  XCTAssertEqual(old.algorithmVersion, 2)
  XCTAssertEqual(city.quotes[0].basePriceCents, old.quotes[0].basePriceCents * 8)
  XCTAssertTrue(StockMarketEngine.validate(city))
  let preview = try StockMarketEngine.estimateBuy(city, player: 0, symbol: "VTL", shares: 10)
  XCTAssertEqual(preview.grossCash, 1480)
  XCTAssertEqual(preview.fee, 3)
  var repeated = city
  for _ in 0..<120 {
   XCTAssertEqual(try StockMarketEngine.advance(&city), try StockMarketEngine.advance(&repeated))
   XCTAssertEqual(city, repeated)
   XCTAssertTrue(StockMarketEngine.validate(city))
  }
 }
 func testNewModeSurvivesExistingGameStateCodableFields() throws {
  let initial = VeilopolyCityLongEconomy.make(seed: 7827)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let restored = try JSONDecoder().decode(GameState.self, from: encoder.encode(initial))
  XCTAssertEqual(initial, restored)
  XCTAssertEqual(StateDigest.hash(initial), StateDigest.hash(restored))
  XCTAssertEqual(restored.banking?.financeRuleVersion, 3)
  XCTAssertEqual(restored.banking?.market?.algorithmVersion, 3)
 }
}
