import Foundation
import XCTest
@testable import VeilopolyEngine

final class SystemicRiskV5Tests: XCTestCase {
 private func execute(_ g: inout GameState, _ move: Move) throws {
  let transition = try VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move).get()
  g = transition.0
 }
 private func total(_ g: GameState) -> Int {
  g.players.reduce(0) { $0 + $1.cash } + (g.banking?.reserveCash ?? 0)
 }

 func testOpeningReservesIncludeCreditBudget() throws {
  let v5 = VeilopolyCityLongEconomy.make(seed: 91801)
  let info = try XCTUnwrap(VeilopolyFinancialStability.inspect(v5))
  XCTAssertEqual(info.totalSupply, 2_100_000)
  XCTAssertEqual(info.treasuryCash, 2_000_000)
  XCTAssertEqual(info.circulatingCash, 100_000)
  XCTAssertEqual(info.level, .stable)
  XCTAssertEqual(info.futureObligations, 0)
  XCTAssertEqual(info.protectedReserve, 252_000)
  XCTAssertEqual(info.safeNewCredit, 525_000)
  XCTAssertEqual(total(v5), 2_100_000)
  XCTAssertNil(VeilopolyFinancialStability.inspect(
   VeilopolyCityLongEconomy.makeV4(seed: 91801)))
 }

 func testCrisisFreezesCreditWithoutDeclaringAllPlayersBankrupt() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 91802)
  g.players[0].cash += 1_990_000
  g.banking?.reserveCash = 10_000
  g.turn.phase = .manage
  let info = try XCTUnwrap(VeilopolyFinancialStability.inspect(g))
  XCTAssertEqual(total(g), 2_100_000)
  XCTAssertEqual(info.level, .crisis)
  XCTAssertEqual(info.safeNewCredit, 0)
  XCTAssertLessThan(VeilopolyCityLongEconomy.marketPressure(g), 0)
  let hash = StateDigest.hash(g)
  guard case .failure(.bankLiquidity) = VeilopolyEngine.apply(
   g, VeilopolyEngine.context(g),
   Move(.bankBorrow, player: 0, seq: 0, amount: 5_000, financePeriods: 4)
  ) else { return XCTFail("Unsafe discretionary lending must be denied") }
  XCTAssertEqual(StateDigest.hash(g), hash)
  XCTAssertFalse(g.players.contains(where: { $0.bankrupt }))
 }

 func testMaturedDepositBecomesClaimAndIncomingCashRepaysIt() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 91803)
  g.turn.phase = .manage
  try execute(&g, Move(.bankDeposit, player: 0, seq: 0,
                       amount: 10_000, financeProduct: .demandDeposit))
  let savingID = try XCTUnwrap(g.banking?.accounts[0].savings.first?.id)
  let previousBank = try XCTUnwrap(g.banking?.reserveCash)
  g.players[0].cash += previousBank - 1_000
  g.banking?.reserveCash = 1_000
  g.banking?.completedTurns = 1
  XCTAssertEqual(total(g), 2_100_000)
  try execute(&g, Move(.bankWithdraw, player: 0, seq: g.nextSeq,
                       financeID: savingID))
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 9_150)
  XCTAssertTrue(g.banking?.accounts[0].savings.isEmpty ?? false)
  XCTAssertEqual(total(g), 2_100_000)
  let priorCash = g.players[0].cash
  g.turn.player = 1; g.turn.phase = .manage
  try execute(&g, Move(.bankDeposit, player: 1, seq: g.nextSeq,
                       amount: 2_000, financeProduct: .demandDeposit))
  XCTAssertEqual(g.players[0].cash, priorCash + 2_000)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 7_150)
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(total(g), 2_100_000)
 }

 func testStockSaleUnderPanicConvertsShortfallToRecordedClaim() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 91804)
  g.turn.phase = .manage
  try execute(&g, Move(.stockBuy, player: 0, seq: 0,
                       stockSymbol: "VTL", stockShares: 10))
  let reserve = try XCTUnwrap(g.banking?.reserveCash)
  g.players[0].cash += reserve - 1_000
  g.banking?.reserveCash = 1_000
  XCTAssertEqual(total(g), 2_100_000)
  try execute(&g, Move(.stockSell, player: 0, seq: g.nextSeq,
                       stockSymbol: "VTL", stockShares: 10))
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.source, "stockExit")
  XCTAssertGreaterThan(g.banking?.queuedClaims?.first?.amount ?? 0, 0)
  XCTAssertTrue(g.banking?.market?.portfolios[0].positions.isEmpty ?? false)
  XCTAssertEqual(total(g), 2_100_000)
 }

 func testPriorClaimStopsNewLoansEvenWhenTreasuryIsPositive() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 91805)
  g.turn.phase = .manage
  g.banking?.queuedClaims = [VeilopolyBankClaim(
   player: 1, amount: 1_000, source: "stockExit")]
  let risk = try XCTUnwrap(VeilopolyFinancialStability.inspect(g))
  XCTAssertEqual(risk.level, .guarded)
  XCTAssertEqual(risk.safeNewCredit, 0)
  guard case .failure(.bankLiquidity) = VeilopolyEngine.apply(
   g, VeilopolyEngine.context(g),
   Move(.bankBorrow, player: 0, seq: 0, amount: 2_000, financePeriods: 2)
  ) else { return XCTFail("Bank must prioritize existing claims") }
 }

 func testHistoricalV4LoanRulesRemainSeparate() throws {
  var old = VeilopolyCityLongEconomy.makeV4(seed: 91806)
  old.turn.phase = .manage
  let reserve = try XCTUnwrap(old.banking?.reserveCash)
  XCTAssertNil(VeilopolyFinancialStability.inspect(old))
  try execute(&old, Move(.bankBorrow, player: 0, seq: 0,
                         amount: 1_000, financePeriods: 6))
  XCTAssertEqual(old.banking?.accounts[0].loans.first?.totalDue, 1_080)
  XCTAssertEqual(old.banking?.reserveCash, reserve - 1_000)
  XCTAssertEqual(total(old), 188_800)
 }
}
