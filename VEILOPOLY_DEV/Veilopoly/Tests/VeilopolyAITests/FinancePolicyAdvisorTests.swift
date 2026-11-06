import XCTest
import VeilopolyEngine
@testable import VeilopolyAI

final class FinancePolicyAdvisorTests: XCTestCase {
 func testAbsentLedgerKeepsExistingAIReserves() {
  let g = GameFactory.make(seed: 91, humanCount: 0)
  let r = FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 250)
  XCTAssertEqual(r.reserve, 250)
  XCTAssertEqual(r.dueWithinHorizon, 0)
  XCTAssertEqual(r.shortfall, 0)
  XCTAssertNil(r.nextLegalBankMove)
 }

 func testNearTermLoanRaisesReserveBeforePropertyPurchase() {
  var g = GameFactory.make(seed: 47, humanCount: 0)
  var ledger = IntegratedBankLedger(completedTurns: 2)
  ledger.accounts[0].loans = [
   .init(id: 3, principal: 1000, interestBasisPoints: 2000,
         duePeriod: 3, periods: 1, totalDue: 1200)]
  g.banking = ledger
  g.players[0].cash = 1250 // 1250 - 60 < known 1200 due next turn
  let r = FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 450)
  XCTAssertEqual(r.dueNow, 0)
  XCTAssertEqual(r.dueWithinHorizon, 1200)
  XCTAssertEqual(r.reserve, 1200)
  g.turn.phase = .tileResolve
  g.turn.pendingPurchase = 1
  let ai = VeilopolyAI.decide(g, VeilopolyEngine.context(g), me: 0, level: .conservative)
  XCTAssertEqual(ai.type, .startAuction)
 }

 func testMatureLoanShowsShortfallAndRetainsLegalNextMove() {
  var g = GameFactory.make(seed: 2, humanCount: 0)
  g.players[0].cash = 80
  g.turn.phase = .manage
  var ledger = IntegratedBankLedger(completedTurns: 5)
  ledger.accounts[0].loans = [
   .init(id: 2, principal: 100, interestBasisPoints: 2000,
         duePeriod: 5, periods: 1, totalDue: 120)]
  ledger.accounts[0].savings = [
   .init(id: 1, feature: .demandDeposit, principal: 90,
         unlockPeriod: 0, payoutBasisPoints: 0)]
  g.banking = ledger
  let r = FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 20)
  XCTAssertEqual(r.shortfall, 40)
  XCTAssertEqual(r.nextLegalBankMove?.type, .bankWithdraw)
  XCTAssertEqual(r.nextLegalBankMove?.financeID, 1)
 }

 func testNoExternalRNGOrMutationAcrossSeedCorpus() {
  for seed in 0..<320 {
   var g = GameFactory.make(seed: UInt64(seed), humanCount: 0)
   var ledger = IntegratedBankLedger(completedTurns: seed % 6)
   ledger.accounts[0].loans = [
    .init(id: 20, principal: 200, interestBasisPoints: 2000,
          duePeriod: seed % 7, periods: 1, totalDue: 240)]
   g.banking = ledger
   let before = StateDigest.hash(g)
   let x = FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 250)
   let y = FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 250)
   XCTAssertEqual(x, y)
   XCTAssertEqual(StateDigest.hash(g), before)
  }
 }

 func testMultipleDebtsAreCountedWithoutOverflow() {
  var g = GameFactory.make(seed: 1, humanCount: 0)
  var ledger = IntegratedBankLedger(completedTurns: 0)
  ledger.accounts[0].loans = [
   .init(id: 1, principal: 999_999_999, interestBasisPoints: 0,
         duePeriod: 1, periods: 1, totalDue: 999_999_999),
   .init(id: 2, principal: 999_999_999, interestBasisPoints: 0,
         duePeriod: 1, periods: 1, totalDue: 999_999_999)]
  g.banking = ledger
  XCTAssertEqual(FinancePolicyAdvisor.analyze(g, player: 0, baseReserve: 100).reserve, 1_000_000_000)
 }
}
