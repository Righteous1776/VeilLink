import Foundation
import XCTest
@testable import VeilopolyEngine

/// Expanded V5 denomination and the nonminting treasury contract.
final class CityExpandedLiquidityTests: XCTestCase {
 private func advance(_ state: inout GameState, _ move: Move) throws -> [Effect] {
  let (next, effects) = try VeilopolyEngine.apply(state, VeilopolyEngine.context(state), move).get()
  state = next
  return effects
 }
 private func money(_ game: GameState) -> Int {
  VeilopolyCityLongEconomy.circulatingCash(game) + (game.banking?.reserveCash ?? 0)
 }
 func testV5MoneyStockAndV4SupplyRemainIsolated() throws {
  let game = VeilopolyCityLongEconomy.make(seed: 41501)
  let old = VeilopolyCityLongEconomy.makeV4(seed: 41501)
  XCTAssertEqual(game.banking?.financeRuleVersion, 5)
  XCTAssertEqual(game.players.map(\.cash), [25_000,25_000,25_000,25_000])
  XCTAssertEqual(game.banking?.reserveCash, 2_000_000)
  XCTAssertEqual(VeilopolyCityLongEconomy.supplyCeiling(game), 2_100_000)
  XCTAssertEqual(money(game), 2_100_000)
  XCTAssertEqual(old.banking?.financeRuleVersion, 4)
  XCTAssertEqual(money(old), 188_800)
  XCTAssertEqual(VeilopolyCityLongEconomy.supplyCeiling(old), 188_800)
  XCTAssertTrue(IntegratedBanking.validate(try XCTUnwrap(game.banking)))
  XCTAssertTrue(IntegratedBanking.validate(try XCTUnwrap(old.banking)))
  XCTAssertEqual(game.board[1].price, 720)
  XCTAssertEqual(game.board[1].houseCost, 600)
  XCTAssertEqual(game.board[1].rent[0], 16)
  XCTAssertEqual(VeilopolyCityLongEconomy.salary(game), 3_200)
  XCTAssertEqual(VeilopolyCityLongEconomy.salary(old), 1_100)
  XCTAssertEqual(VeilopolyCityLongEconomy.tax(game, tile: 4), 2_200)
  XCTAssertEqual(VeilopolyCityLongEconomy.rentCeiling(game), 3_200)
  XCTAssertEqual(VeilopolyCityLongEconomy.rentCeiling(old), 900)
 }
 func testV5LoansAreScaledAndNeverMintExtraCurrency() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 41502)
  game.turn.phase = .manage
  let reserve = try XCTUnwrap(game.banking?.reserveCash)
  _ = try advance(&game, Move(.bankBorrow, player: 0, seq: 0,
                              amount: 5_000, financePeriods: 6))
  XCTAssertEqual(game.players[0].cash, 30_000)
  XCTAssertEqual(game.banking?.reserveCash, reserve - 5_000)
  XCTAssertEqual(game.banking?.accounts[0].loans[0].totalDue, 5_325)
  XCTAssertEqual(money(game), 2_100_000)
  let availableAfterLoan = try XCTUnwrap(game.banking?.reserveCash)
  _ = try advance(&game, Move(.transferCash, player: 0, seq: game.nextSeq,
                              amount: 4_000, to: 1))
  XCTAssertEqual(game.players[0].cash, 26_000)
  XCTAssertEqual(game.players[1].cash, 29_000)
  XCTAssertEqual(game.banking?.reserveCash, availableAfterLoan)
  XCTAssertEqual(money(game), 2_100_000)
 }
 func testV5InvestmentSpendingAndPassingGoRemainConserved() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 41503)
  game.turn.phase = .manage
  let bank = try XCTUnwrap(game.banking?.reserveCash)
  _ = try advance(&game, Move(.bankDeposit, player: 0, seq: 0,
                              amount: 8_000, financeProduct: .demandDeposit))
  XCTAssertEqual(game.banking?.reserveCash, bank + 8_000)
  XCTAssertEqual(money(game), 2_100_000)
  game.players[0].position = 38; game.turn.phase = .moveAnim
  game.turn.pendingSteps = 4
  let earned = try advance(&game, Move(.applyMovement, player: 0, seq: game.nextSeq))
  XCTAssertTrue(earned.contains { $0.kind == .passedGo && $0.amount == 3_200 })
  XCTAssertEqual(money(game), 2_100_000)
 }
 func testV5CardValuesAreExactAndLegacyV4CardsRemainFrozen() throws {
  let expanded = VeilopolyCityLongCards.allV5
  XCTAssertEqual(expanded.count, 32)
  XCTAssertEqual(expanded.map(\.id), Array(0..<32))
  let v4 = VeilopolyCityLongCards.allV4
  XCTAssertEqual(v4.count, 32)
  XCTAssertEqual(v4[5].effects.first?.amount, 650)
  XCTAssertEqual(expanded[5].effects.first?.amount, 2_600)
  XCTAssertTrue(expanded[5].text.contains("¥2600"))
  XCTAssertEqual(v4[13].effects.first?.amount, 800)
  XCTAssertEqual(expanded[13].effects.first?.amount, 3_200)
  XCTAssertTrue(expanded[13].text.contains("¥3,200") || expanded[13].text.contains("¥3200"))
  XCTAssertNotNil(VeilopolyCityLongCards.presentation(for: expanded[13]))
  XCTAssertNotNil(VeilopolyCityLongCards.presentation(for: v4[13]))
 }
 func testV5FateCardCreatesCashFlowFromTreasuryNotNewSupply() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 41504)
  game.players[0].position = 7
  game.turn.phase = .tileResolve
  game.chanceDeck = DeckState(order: [5])
  let old = game.banking!.reserveCash!
  let effects = try advance(&game, Move(.resolveTile, player: 0, seq: 0))
  XCTAssertEqual(game.players[0].cash, 27_600)
  XCTAssertEqual(game.banking?.reserveCash, old - 2_600)
  XCTAssertTrue(effects.contains { $0.kind == .cashChanged && $0.amount == 2_600 })
  XCTAssertEqual(money(game), 2_100_000)
 }
 func testV5StockNominalPricesIncreaseWithoutTouchingV4Quotes() throws {
  let expanded = VeilopolyCityLongEconomy.make(seed: 41505)
  let classic = VeilopolyCityLongEconomy.makeV4(seed: 41505)
  let v5 = try XCTUnwrap(expanded.banking?.market?.quotes.first)
  let v4 = try XCTUnwrap(classic.banking?.market?.quotes.first)
  XCTAssertEqual(v4.basePriceCents, 1_850 * 8)
  XCTAssertEqual(v5.basePriceCents, 1_850 * 24)
  XCTAssertEqual(v5.currentPriceCents, v5.basePriceCents)
  XCTAssertEqual(expanded.banking?.market?.algorithmVersion, 3)
  XCTAssertEqual(classic.banking?.market?.algorithmVersion, 3)
 }
 func testOlderV4CheckpointWithNoClaimListIsStillValid() throws {
  var prior = VeilopolyCityLongEconomy.makeV4(seed: 41506)
  prior.banking?.queuedClaims = nil
  XCTAssertTrue(IntegratedBanking.validate(try XCTUnwrap(prior.banking)))
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(prior)
  let decoded = try JSONDecoder().decode(GameState.self, from: data)
  XCTAssertEqual(decoded.banking?.queuedClaims, nil)
  XCTAssertEqual(StateDigest.hash(decoded), StateDigest.hash(prior))
  prior.turn.phase = .manage
  let balance = prior.banking!.reserveCash!
  _ = try advance(&prior, Move(.bankBorrow, player: 0, seq: 0, amount: 500, financePeriods: 1))
  XCTAssertEqual(prior.banking?.reserveCash, balance - 500)
  XCTAssertEqual(money(prior), 188_800)
 }
 func testInvalidV5CurrencySupplyDoesNotCommit() {
  var game = VeilopolyCityLongEconomy.make(seed: 41507)
  game.players[1].cash += 100
  let originalHash = StateDigest.hash(game)
  let result = VeilopolyEngine.apply(game, VeilopolyEngine.context(game),
                                     Move(.rollDice, player: 0, seq: 0))
  guard case .failure(.invalidState) = result else {
   return XCTFail("Tampered currency supply must not be accepted")
  }
  XCTAssertEqual(StateDigest.hash(game), originalHash)
 }
}
