import Foundation
import XCTest
@testable import VeilopolyEngine

/// V5 bankruptcy cannot mint fictional bank money from a noncash estate.
final class SystemicRiskV5EstateTests: XCTestCase {
 private func transition(_ g: inout GameState, _ move: Move) throws -> [Effect] {
  let (next, effects) = try VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move).get()
  g = next
  return effects
 }
 private func supply(_ g: GameState) -> Int {
  g.players.reduce(0) { $0 + $1.cash } + (g.banking?.reserveCash ?? 0)
 }

 func testBankruptEstateTransfersDepositsPositionsSharesAndBankClaimsToPlayerCreditor() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 92901)
  g.turn.phase = .manage
  try transition(&g, Move(.bankDeposit, player: 0, seq: 0,
                          amount: 1_000, financeProduct: .demandDeposit))
  let fundSeq = g.nextSeq
  try transition(&g, Move(.bankInvest, player: 0, seq: fundSeq,
                          amount: 1_000, financeProduct: .managedFund))
  let stockSeq = g.nextSeq
  try transition(&g, Move(.stockBuy, player: 0, seq: stockSeq,
                          stockSymbol: "VTL", stockShares: 10))
  let oldBank = try XCTUnwrap(g.banking?.reserveCash)
  // In a panic, the bank holds no cash but its obligations still survive.
  g.players[2].cash += oldBank
  g.banking?.reserveCash = 0
  g.banking?.queuedClaims?.append(
    VeilopolyBankClaim(player: 0, amount: 5_000, source: "eventCash"))
  let allCash = g.players.reduce(0) { $0 + $1.cash }
  let receiverBefore = g.players[1].cash
  let debtorBefore = g.players[0].cash
  g.turn.phase = .debt
  g.pendingDebt = PendingDebt(player: 0, amount: debtorBefore + 1_000, creditor: 1)
  XCTAssertEqual(supply(g), 2_100_000)
  let seq = g.nextSeq
  let fx = try transition(&g, Move(.declareBankruptcy, player: 0, seq: seq))
  XCTAssertEqual(g.players[0].cash, 0)
  XCTAssertTrue(g.players[0].bankrupt)
  XCTAssertEqual(g.players[1].cash, receiverBefore + debtorBefore)
  XCTAssertEqual(g.players.reduce(0) { $0 + $1.cash }, allCash)
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(supply(g), 2_100_000)
  XCTAssertTrue(g.banking?.accounts[0].savings.isEmpty ?? false)
  XCTAssertTrue(g.banking?.accounts[0].positions.isEmpty ?? false)
  XCTAssertEqual(g.banking?.accounts[1].savings.count, 1)
  XCTAssertEqual(g.banking?.accounts[1].positions.count, 1)
  XCTAssertEqual(g.banking?.market?.portfolios[1].positions.first?.shares, 10)
  XCTAssertTrue(g.banking?.market?.portfolios[0].positions.isEmpty ?? false)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.player, 1)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 5_000)
  XCTAssertTrue(fx.contains { $0.kind == .liquidation &&
    $0.text == "noncashBankruptcyEstate" })
  XCTAssertTrue(IntegratedBanking.validate(try XCTUnwrap(g.banking)))
 }

 func testBankCreditorDoesNotRedeemTheDebtorFinancialAssetsDuringCrisis() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 92902)
  g.turn.phase = .manage
  try transition(&g, Move(.bankDeposit, player: 0, seq: 0,
                          amount: 3_000, financeProduct: .demandDeposit))
  let stockSeq = g.nextSeq
  try transition(&g, Move(.stockBuy, player: 0, seq: stockSeq,
                          stockSymbol: "VTL", stockShares: 4))
  let bank = try XCTUnwrap(g.banking?.reserveCash)
  g.players[2].cash += bank
  g.banking?.reserveCash = 0
  g.banking?.queuedClaims?.append(
    VeilopolyBankClaim(player: 0, amount: 3_500, source: "stockExit"))
  let startingCash = g.players[0].cash
  g.turn.phase = .debt
  g.pendingDebt = PendingDebt(player: 0, amount: startingCash + 1, creditor: nil)
  let next = g.nextSeq
  _ = try transition(&g, Move(.declareBankruptcy, player: 0, seq: next))
  XCTAssertTrue(g.players[0].bankrupt)
  XCTAssertEqual(g.players[0].cash, 0)
  XCTAssertEqual(g.banking?.reserveCash, startingCash)
  XCTAssertTrue(g.banking?.accounts[0].savings.isEmpty ?? false)
  XCTAssertTrue(g.banking?.market?.portfolios[0].positions.isEmpty ?? false)
  XCTAssertTrue(g.banking?.queuedClaims?.allSatisfy { $0.player != 0 } ?? false)
  XCTAssertEqual(supply(g), 2_100_000)
 }

 func testExcessInheritedStockBecomesExplicitBankClaimNotForgedCash() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 92903)
  var market = try XCTUnwrap(g.banking?.market)
  let quote = try XCTUnwrap(market.quotes.first { $0.symbol == "VTL" })
  market.portfolios[0].positions = [StockPosition(symbol: "VTL",
    shares: 100, averageCostCents: quote.currentPriceCents)]
  market.portfolios[1].positions = [StockPosition(symbol: "VTL",
    shares: 100_000, averageCostCents: quote.currentPriceCents)]
  g.banking?.market = market
  let oldBank = try XCTUnwrap(g.banking?.reserveCash)
  g.players[2].cash += oldBank
  g.banking?.reserveCash = 0
  let receiverCash = g.players[1].cash
  let debtorCash = g.players[0].cash
  g.turn.phase = .debt
  g.pendingDebt = PendingDebt(player: 0, amount: debtorCash + 1, creditor: 1)
  let seq = g.nextSeq
  _ = try transition(&g, Move(.declareBankruptcy, player: 0, seq: seq))
  XCTAssertEqual(g.banking?.market?.portfolios[1].positions.first?.shares, 100_000)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.source, "estateStock")
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount,
                 100 * quote.currentPriceCents / 100)
  XCTAssertEqual(g.players[1].cash, receiverCash + debtorCash)
  XCTAssertEqual(supply(g), 2_100_000)
 }

 func testV4BankruptcyKeepsOriginalEstateSettlementLogic() throws {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 92904)
  g.turn.phase = .debt
  g.pendingDebt = PendingDebt(player: 0, amount: 8_000, creditor: 1)
  let seq = g.nextSeq
  _ = try transition(&g, Move(.declareBankruptcy, player: 0, seq: seq))
  XCTAssertTrue(g.players[0].bankrupt)
  XCTAssertEqual(supply(g), 188_800)
  XCTAssertEqual(g.banking?.financeRuleVersion, 4)
 }
}
