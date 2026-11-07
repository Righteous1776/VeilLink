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

extension IntegratedBankingTests {
 func testUnlockedSavingsLiquidateBeforeRentCausesBankruptcy() throws {
  var g = Fixture.game(.manage)
  let deposit = Move(.bankDeposit, player: 0, seq: g.nextSeq, amount: 400,
                     financeProduct: .demandDeposit)
  switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), deposit) {
  case .success((let next, _)): g = next
  case .failure(let e): throw e
  }
  g.players[0].cash = 10
  var effects: [Effect] = []
  IntegratedBanking.releaseAvailableSavingsForDebt(&g, debtor: 0, amount: 300, effects: &effects)
  XCTAssertEqual(g.players[0].cash, 410)
  XCTAssertEqual(g.banking?.accounts[0].savings.count, 0)
  XCTAssertEqual(effects.first?.kind, .bankWithdrawn)
  XCTAssertEqual(effects.first?.text, "automaticDebtCover")
 }
 func testLockedFixedSavingsCannotAutoRelease() throws {
  var g = Fixture.game(.manage)
  var policy = FinanceSandboxPolicy()
  policy.fixedYieldBasisPoints = 500
  policy.fixedLockPeriods = 5
  g = try XCTUnwrap(IntegratedBanking.configured(g, terms: policy))
  let m = Move(.bankDeposit, player: 0, seq: 0, amount: 400, financeProduct: .fixedDeposit)
  switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), m) {
  case .success((let next, _)): g = next
  case .failure(let e): throw e
  }
  g.players[0].cash = 10
  var effects: [Effect] = []
  IntegratedBanking.releaseAvailableSavingsForDebt(&g, debtor: 0, amount: 300, effects: &effects)
  XCTAssertEqual(g.players[0].cash, 10)
  XCTAssertEqual(g.banking?.accounts[0].savings.count, 1)
  XCTAssertTrue(effects.isEmpty)
 }
}

extension IntegratedBankingTests {
 func testMaturityAutomaticallyCollectsOnlyActualContractAmount() {
  var g=Fixture.game(.manage)
  var bank=IntegratedBankLedger(completedTurns:0)
  XCTAssertEqual(bank.financeRuleVersion,2)
  bank.accounts[0].loans=[
   SandboxLoan(id:71,principal:200,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:240)]
  g.banking=bank
  let cashBefore=g.players[0].cash
  var events:[Effect]=[]
  IntegratedBanking.advanceTurn(&g,effects:&events)
  XCTAssertEqual(g.players[0].cash,cashBefore-240)
  XCTAssertEqual(g.banking?.accounts[0].loans.count,0)
  XCTAssertTrue(events.contains {
   $0.kind == .bankRepaid && $0.amount == -240 && $0.text == "automaticMaturity"
  })
  XCTAssertEqual(g.banking?.financeRuleVersion,2)
 }
 func testOverdueLoanPreventsBuyingButAllowsRepayment() throws {
  var g=Fixture.game(.manage)
  var bank=IntegratedBankLedger(completedTurns:7)
  bank.accounts[0].loans=[
   SandboxLoan(id:72,principal:500,interestBasisPoints:2000,
               duePeriod:6,periods:1,totalDue:600)]
  g.banking=bank
  fails(g, Move(.stockBuy,player:0,seq:g.nextSeq,
                stockSymbol:"VTL",stockShares:1),.financeOverdue)
  fails(g, Move(.bankDeposit,player:0,seq:g.nextSeq,
                amount:30,financeProduct:.demandDeposit),.financeOverdue)
  _=try apply(&g,.bankRepay,id:72)
  XCTAssertTrue(g.banking?.accounts[0].loans.isEmpty == true)
  let test=Move(.stockBuy,player:0,seq:g.nextSeq,
                stockSymbol:"VTL",stockShares:1)
  let (next,_) = try VeilopolyEngine.apply(g,VeilopolyEngine.context(g),test).get()
  XCTAssertEqual(next.banking?.market?.portfolios[0].position(symbol:"VTL")?.shares,1)
 }
 func testInsufficientCashDoesNotDestroyMaturedDebt() {
  var g=Fixture.game(.manage)
  g.players[0].cash=10
  var bank=IntegratedBankLedger(completedTurns:0)
  bank.accounts[0].loans=[
   SandboxLoan(id:73,principal:100,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:120)]
  g.banking=bank
  var events:[Effect]=[]
  IntegratedBanking.advanceTurn(&g,effects:&events)
  XCTAssertEqual(g.players[0].cash,10)
  XCTAssertEqual(g.banking?.accounts[0].loans.first?.totalDue,120)
  XCTAssertFalse(events.contains { $0.kind == .bankRepaid })
  XCTAssertTrue(events.contains { $0.kind == .bankMatured })
 }
 func testLegacyLedgerKeepsBytesAndDoesNotAutoRepay() throws {
  var ledger=IntegratedBankLedger(completedTurns:0,financeRuleVersion:1)
  ledger.accounts[0].loans=[
   SandboxLoan(id:74,principal:100,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:120)]
  let encoder=JSONEncoder(); encoder.outputFormatting=[.sortedKeys]
  let json=try encoder.encode(ledger)
  XCTAssertFalse(try XCTUnwrap(String(data:json,encoding:.utf8)).contains("financeRuleVersion"))
  let restored=try JSONDecoder().decode(IntegratedBankLedger.self,from:json)
  XCTAssertEqual(restored.financeRuleVersion,1)
  XCTAssertEqual(try encoder.encode(restored),json)
  var g=Fixture.game(.manage); g.banking=restored
  let initialCash=g.players[0].cash
  var effects:[Effect]=[]
  IntegratedBanking.advanceTurn(&g,effects:&effects)
  XCTAssertEqual(g.players[0].cash,initialCash)
  XCTAssertEqual(g.banking?.accounts[0].loans.count,1)
 }
 func testMaturityPrioritizesOldestContractBeforeYoungerDebt() {
  var g=Fixture.game(.manage)
  g.players[0].cash=250
  var ledger=IntegratedBankLedger(completedTurns:2)
  ledger.accounts[0].loans=[
   SandboxLoan(id:91,principal:90,interestBasisPoints:2000,
               duePeriod:2,periods:1,totalDue:100),
   SandboxLoan(id:90,principal:190,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:200)]
  g.banking=ledger
  var effects:[Effect]=[]
  IntegratedBanking.advanceTurn(&g,effects:&effects)
  XCTAssertEqual(g.players[0].cash,50)
  XCTAssertEqual(g.banking?.accounts[0].loans.map(\.id),[91])
  XCTAssertEqual(effects.filter { $0.kind == .bankRepaid }.map(\.amount),[-200])
 }
}

extension IntegratedBankingTests {
 func testBankruptcyCashCapNeverSilentlyDeletesAccountAssets() {
  var g=Fixture.game(.manage)
  g.players[0].cash=1_000_000_000
  var ledger=IntegratedBankLedger()
  ledger.accounts[0].savings=[
   SandboxSaving(id:2,feature:.demandDeposit,principal:120,
                 unlockPeriod:0,payoutBasisPoints:0)]
  g.banking=ledger
  let before=g
  var effects:[Effect]=[]
  XCTAssertThrowsError(try IntegratedBanking.closeBankruptAccount(
   &g,player:0,effects:&effects)) {
   XCTAssertEqual($0 as? GameError,.invalidState)
  }
  XCTAssertEqual(g,before)
  XCTAssertTrue(effects.isEmpty)
 }
 func testFailedBankruptcyIsFullyAtomicIncludingTheActualReducer() {
  var g=Fixture.game(.manage)
  g.players[0].cash=1_000_000_000
  var ledger=IntegratedBankLedger()
  ledger.accounts[0].savings=[
   SandboxSaving(id:3,feature:.demandDeposit,principal:100,
                 unlockPeriod:0,payoutBasisPoints:0)]
  g.banking=ledger
  g.pendingDebt=PendingDebt(player:0,amount:1_000_000,creditor:1)
  g.turn.phase = .debt
  let previous=g
  let result=VeilopolyEngine.apply(g,VeilopolyEngine.context(g),
      Move(.declareBankruptcy,player:0,seq:g.nextSeq))
  switch result {
  case .failure(let error): XCTAssertEqual(error,.invalidState)
  case .success: XCTFail("The estate must never discard assets to satisfy the cap")
  }
  XCTAssertEqual(g,previous)
  XCTAssertEqual(g.banking?.accounts[0].savings.count,1)
 }
}

extension IntegratedBankingTests {
 func testRepeatedFinancialPositionIDsCannotDeleteTwoDebtsForOneRepayment() {
  var ledger=IntegratedBankLedger(completedTurns:2)
  ledger.accounts[0].loans=[
   SandboxLoan(id:42,principal:100,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:120),
   SandboxLoan(id:42,principal:200,interestBasisPoints:2000,
               duePeriod:2,periods:1,totalDue:240)]
  XCTAssertFalse(IntegratedBanking.validate(ledger))
  var game=Fixture.game(.manage)
  game.banking=ledger
  fails(game,Move(.bankRepay,player:0,seq:game.nextSeq,
                  financeID:42),.invalidState)
 }
 func testDistinctBankIdsRemainValidAcrossProductKinds() {
  var ledger=IntegratedBankLedger(completedTurns:2)
  ledger.accounts[0].loans=[
   SandboxLoan(id:42,principal:100,interestBasisPoints:2000,
               duePeriod:1,periods:1,totalDue:120)]
  ledger.accounts[0].savings=[
   SandboxSaving(id:43,feature:.demandDeposit,principal:100,
                 unlockPeriod:0,payoutBasisPoints:0)]
  XCTAssertTrue(IntegratedBanking.validate(ledger))
 }
}

extension IntegratedBankingTests {
 func testNewInvestmentSettlementCannotBeRerolledByDelayingClaim() throws {
  var initial=Fixture.game(.manage)
  var policy=FinanceSandboxPolicy()
  policy.payouts[.stockSimulation]=[0,2500,5000,10000,15000,20000]
  initial=try XCTUnwrap(IntegratedBanking.configured(initial,terms:policy))
  _=try apply(&initial,.bankInvest,amount:100,product:.stockSimulation)
  let id=try XCTUnwrap(initial.banking?.accounts[0].positions.first?.id)
  var immediate=initial
  immediate.banking?.completedTurns=3
  let diceBefore=immediate.rngCounter
  let fxNow=try apply(&immediate,.bankSettle,id:id)
  XCTAssertEqual(immediate.rngCounter,diceBefore)
  var late=initial
  late.rngCounter = initial.rngCounter &+ 123
  late.banking?.completedTurns=8
  let laterCounter=late.rngCounter
  let fxLater=try apply(&late,.bankSettle,id:id)
  XCTAssertEqual(late.rngCounter,laterCounter)
  XCTAssertEqual(fxNow.first?.dice,fxLater.first?.dice)
  XCTAssertEqual(fxNow.first?.amount,fxLater.first?.amount)
  XCTAssertEqual(immediate.players[0].cash,late.players[0].cash)
 }
 func testLegacyInvestmentSettlementStillConsumesOriginalDiceRNG() throws {
  var g=Fixture.game(.manage)
  var policy=FinanceSandboxPolicy()
  policy.payouts[.stockSimulation]=[0,2500,5000,10000,15000,20000]
  g=try XCTUnwrap(IntegratedBanking.configured(g,terms:policy))
  g.banking?.financeRuleVersion=1
  _=try apply(&g,.bankInvest,amount:100,product:.stockSimulation)
  let id=try XCTUnwrap(g.banking?.accounts[0].positions.first?.id)
  g.banking?.completedTurns=3
  let before=g.rngCounter
  _=try apply(&g,.bankSettle,id:id)
  XCTAssertEqual(g.rngCounter,before+1)
 }
}
