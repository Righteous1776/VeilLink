import XCTest
@testable import VeilopolyEngine

final class IntegratedBankingTests: XCTestCase {
 private func game() -> GameState { Fixture.game(.manage) }
 private func apply(_ game: inout GameState, _ kind: MoveKind, amount: Int? = nil,
                    product: FinancialFeature? = nil, periods: Int? = nil, id: Int? = nil) throws -> [Effect] {
  let m = Move(kind, player: game.turn.player, seq: game.nextSeq, amount: amount,
               financeProduct: product, financePeriods: periods, financeID: id)
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), m) {
  case .failure(let e): throw e
  case .success((let next, let effects)): game = next; return effects
  }
 }
 private func fails(_ game: GameState, _ move: Move, _ err: GameError,
                    file: StaticString = #filePath, line: UInt = #line) {
  let before = StateDigest.hash(game)
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move) {
  case .failure(let actual): XCTAssertEqual(actual, err, file: file, line: line)
  case .success: XCTFail("unexpected success", file: file, line: line)
  }
  XCTAssertEqual(StateDigest.hash(game), before, file: file, line: line)
 }
 func testDemandDepositWithdrawIsIntegratedWithSingleCashBalance() throws {
  var g = game()
  let start = g.players[0].cash
  let effects = try apply(&g, .bankDeposit, amount: 300, product: .demandDeposit)
  XCTAssertEqual(g.players[0].cash, start - 300)
  XCTAssertEqual(g.banking?.accounts[0].savings.count, 1)
  XCTAssertEqual(effects.map(\.kind), [.bankDeposited])
  let id = try XCTUnwrap(g.banking?.accounts[0].savings.first?.id)
  _ = try apply(&g, .bankWithdraw, id: id)
  XCTAssertEqual(g.players[0].cash, start)
  XCTAssertEqual(g.banking?.accounts[0].savings.count, 0)
  XCTAssertTrue(g.moveLog.suffix(2).allSatisfy { [.bankDeposit, .bankWithdraw].contains($0.type) })
 }
 func testFixedAndMarketAreBlockedUntilTermsAreApproved() {
  let g = game()
  fails(g, Move(.bankDeposit, player: 0, seq: g.nextSeq, amount: 100,
                financeProduct: .fixedDeposit), .financeTermsPending)
  fails(g, Move(.bankInvest, player: 0, seq: g.nextSeq, amount: 100,
                financeProduct: .stockSimulation), .financeTermsPending)
 }
 func testLoanQuoteAndEarlyRepayment() throws {
  var g = game()
  let effects = try apply(&g, .bankBorrow, amount: 500, periods: 3)
  XCTAssertEqual(effects.first?.kind, .bankBorrowed)
  XCTAssertEqual(g.players[0].cash, 2000)
  let loan = try XCTUnwrap(g.banking?.accounts[0].loans.first)
  XCTAssertEqual(loan.interestBasisPoints, 2000)
  XCTAssertEqual(loan.totalDue, 800)
  XCTAssertEqual(loan.duePeriod, 3)
  // Loans are not automatically due until their term elapses.
  XCTAssertNil(FinancialRuleJudge.recommendation(g, player: 0))
  _ = try apply(&g, .bankRepay, id: loan.id)
  XCTAssertEqual(g.players[0].cash, 1200)
  XCTAssertEqual(g.banking?.accounts[0].loans.count, 0)
 }
 func testFourPlusCollateralIsNotSilentlyClamped() {
  var g = game()
  for tile in [1,3,5,6] { g.board[tile].owner = 0 }
  fails(g, Move(.bankBorrow, player: 0, seq: g.nextSeq, amount: 500,
                financePeriods: 1), .financeTermsPending)
 }
 func testWrongPhaseAndWrongSequenceRejectBankMoveWithoutStateMutation() {
  var g = game()
  fails(g, Move(.bankBorrow, player: 0, seq: 500, amount: 200, financePeriods: 1), .invalidSequence)
  g.turn.phase = .roll
  fails(g, Move(.bankBorrow, player: 0, seq: 0, amount: 200, financePeriods: 1), .wrongPhase)
 }
 func testMaturityAdvancesOnlyAfterCompletedTurn() throws {
  var g = game()
  var policy = FinanceSandboxPolicy()
  policy.fixedYieldBasisPoints = 500
  policy.fixedLockPeriods = 1
  g = try XCTUnwrap(IntegratedBanking.configured(g, terms: policy))
  _ = try apply(&g, .bankDeposit, amount: 200, product: .fixedDeposit)
  let id = try XCTUnwrap(g.banking?.accounts[0].savings.first?.id)
  fails(g, Move(.bankWithdraw, player: 0, seq: g.nextSeq, financeID: id), .financePositionLocked)
  let finished = try apply(&g, .endTurn)
  XCTAssertEqual(g.banking?.completedTurns, 1)
  XCTAssertTrue(finished.contains { $0.kind == .bankMatured && $0.player == 0 })
  // Player #1 is now active. Make an authorized test fixture for owner #0's management turn.
  g.turn.player = 0; g.turn.phase = .manage
  _ = try apply(&g, .bankWithdraw, id: id)
  XCTAssertEqual(g.players[0].cash, 1510) // 1500-200 + 200+10 interest
 }
 func testSeededMarketResultAndReplayHashAreIdentical() throws {
  func play() throws -> GameState {
   var g = game()
   var p = FinanceSandboxPolicy()
   p.payouts[.stockSimulation] = [0,2500,5000,10000,15000,20000]
   g = try XCTUnwrap(IntegratedBanking.configured(g, terms: p))
   let opened = try apply(&g, .bankInvest, amount: 100, product: .stockSimulation)
   XCTAssertEqual(opened.first?.kind, .bankInvestmentOpened)
   let id = try XCTUnwrap(g.banking?.accounts[0].positions.first?.id)
   g.banking?.completedTurns = 3 // clock delivered by a pure host/test state, never Date()
   let settled = try apply(&g, .bankSettle, id: id)
   XCTAssertEqual(settled.first?.kind, .bankInvestmentSettled)
   XCTAssertEqual(settled.first?.dice?.count, 1)
   return g
  }
  let a = try play(), b = try play()
  XCTAssertEqual(a, b)
  XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
 }
 func testOldSnapshotWithoutBankKeyDecodesAndCanOpenBankAction() throws {
  let old = game()
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(old)
  var restored = try JSONDecoder().decode(GameState.self, from: data)
  XCTAssertNil(restored.banking)
  _ = try apply(&restored, .bankDeposit, amount: 100, product: .demandDeposit)
  XCTAssertEqual(restored.banking?.accounts[0].savings.count, 1)
  XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: encoder.encode(restored)), restored)
 }
 func testBankruptPlayersCannotKeepPendingBankInvestments() throws {
  var g = game()
  _ = try apply(&g, .bankDeposit, amount: 300, product: .demandDeposit)
  g.pendingDebt = PendingDebt(player: 0, amount: 3000, creditor: nil)
  g.turn.phase = .debt
  _ = try apply(&g, .declareBankruptcy)
  XCTAssertTrue(g.players[0].bankrupt)
  XCTAssertEqual(g.banking?.accounts[0].savings.count, 0)
 }
 func testBankingMutationNeverChangesCashOnFailedMove() throws {
  var g = game()
  _ = try apply(&g, .bankDeposit, amount: 600, product: .demandDeposit)
  let current = g.players[0].cash
  fails(g, Move(.bankDeposit, player: 0, seq: g.nextSeq, amount: current + 1,
                financeProduct: .demandDeposit), .noCash)
  XCTAssertEqual(g.players[0].cash, current)
 }
}
