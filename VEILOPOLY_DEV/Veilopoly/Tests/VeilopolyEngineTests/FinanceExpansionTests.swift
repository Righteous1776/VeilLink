import XCTest
@testable import VeilopolyEngine

final class FinanceExpansionTests: XCTestCase {
 private func assertError(_ result: FinanceSandbox.Transition, _ code: FinancialSandboxError,
                          file: StaticString = #filePath, line: UInt = #line) {
  switch result {
  case .failure(let actual): XCTAssertEqual(actual, code, file: file, line: line)
  case .success: XCTFail("Expected \(code)", file: file, line: line)
  }
 }

 func testPhotographedLoanInterestAndCollateral() {
  let terms = FinanceSandboxPolicy()
  XCTAssertEqual(terms.loanCapsByProperties, [500, 1000, 4000, 7000])
  XCTAssertEqual(terms.loanInterestBasisPoints, [2000, 3000, 4000, 4500])
  XCTAssertEqual(try? FinanceSandbox.loanQuote(principal: 1000, periods: 3, ownedLots: 1, ordinal: 0).get(), 1600)
  XCTAssertEqual(try? FinanceSandbox.loanQuote(principal: 1000, periods: 3, ownedLots: 1, ordinal: 1).get(), 1900)
  XCTAssertEqual(try? FinanceSandbox.loanQuote(principal: 1000, periods: 3, ownedLots: 1, ordinal: 2).get(), 2200)
  XCTAssertEqual(try? FinanceSandbox.loanQuote(principal: 1000, periods: 3, ownedLots: 1, ordinal: 3).get(), 2350)
  XCTAssertEqual(FinanceSandbox.loanQuote(principal: 1000, periods: 3, ownedLots: 0, ordinal: 0), .failure(.collateralCapExceeded))
 }

 func testBorrowAndRepayOnlyOnMaturity() throws {
  var initial = FinancialSandboxState(seed: 42)
  initial.accounts[0].ownedLots = 1
  let policy = FinanceSandboxPolicy()
  let borrow = FinancialSandboxMove(.borrow, player: 0, seq: 0, amount: 1000, periods: 3)
  var g = try FinanceSandbox.apply(initial, borrow, policy: policy).get().0
  XCTAssertEqual(g.accounts[0].cash, 2500)
  XCTAssertEqual(g.accounts[0].loans.first?.totalDue, 1600)
  assertError(FinanceSandbox.apply(g, .init(.repayLoan, player: 0, seq: g.nextSeq, targetID: 0), policy: policy), .positionLocked)
  for _ in 0..<3 { g = try FinanceSandbox.apply(g, .init(.advancePeriod, player: 0, seq: g.nextSeq), policy: policy).get().0 }
  g = try FinanceSandbox.apply(g, .init(.repayLoan, player: 0, seq: g.nextSeq, targetID: 0), policy: policy).get().0
  XCTAssertEqual(g.accounts[0].cash, 900)
  XCTAssertTrue(g.accounts[0].loans.isEmpty)
  XCTAssertEqual(g.moveLog.count, g.nextSeq)
 }

 func testUnapprovedDepositAndInvestmentHaveNoSideEffects() {
  let initial = FinancialSandboxState(seed: 11)
  let old = initial
  assertError(FinanceSandbox.apply(initial, .init(.deposit, player: 0, seq: 0, amount: 500, feature: .fixedDeposit)), .termsAwaitOwnerRuling)
  assertError(FinanceSandbox.apply(initial, .init(.openInvestment, player: 0, seq: 0, amount: 400, feature: .ventureSimulation)), .termsAwaitOwnerRuling)
  XCTAssertEqual(initial, old)
 }

 func testApprovedDepositAndInvestmentModelAreDeterministic() throws {
  var terms = FinanceSandboxPolicy()
  terms.fixedYieldBasisPoints = 1000 // test fixture, NOT a photographic claim
  terms.fixedLockPeriods = 2
  terms.payouts[.managedFund] = [0, 9300, 9500, 10000, 11500, 15000] // test fixture only
  func replay() throws -> FinancialSandboxState {
   var g = FinancialSandboxState(seed: 2030)
   let start = FinancialSandboxMove(.deposit, player: 0, seq: g.nextSeq, amount: 400, feature: .fixedDeposit)
   g = try FinanceSandbox.apply(g, start, policy: terms).get().0
   g = try FinanceSandbox.apply(g, .init(.openInvestment, player: 0, seq: g.nextSeq, amount: 400, feature: .managedFund), policy: terms).get().0
   for _ in 0..<5 { g = try FinanceSandbox.apply(g, .init(.advancePeriod, player: 0, seq: g.nextSeq), policy: terms).get().0 }
   g = try FinanceSandbox.apply(g, .init(.withdraw, player: 0, seq: g.nextSeq, targetID: 0), policy: terms).get().0
   g = try FinanceSandbox.apply(g, .init(.settleInvestment, player: 0, seq: g.nextSeq, targetID: 1), policy: terms).get().0
   return g
  }
  let a = try replay(), b = try replay()
  XCTAssertEqual(a, b)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  XCTAssertEqual(try encoder.encode(a), try encoder.encode(b))
  XCTAssertEqual(a.accounts[0].savings.count, 0)
  XCTAssertEqual(a.accounts[0].positions.count, 0)
  XCTAssertEqual(a.rngCounter, 1)
 }

 func testNonWagerDiceChallengeChangesScoreOnly() throws {
  let initial = FinancialSandboxState(seed: 9)
  let (next, fx) = try FinanceSandbox.apply(initial, .init(.rollNoStakeChallenge, player: 1, seq: 0)).get()
  XCTAssertEqual(next.accounts[1].cash, 1500)
  XCTAssertEqual(fx.first?.label, "noStakeDice")
  XCTAssertTrue((1...6).contains(fx.first?.rolled ?? 0))
  XCTAssertEqual(next.rngCounter, 1)
 }

 func testReadOnlyShadowDoesNotModifyProductEngine() {
  var original = GameFactory.make(seed: 789)
  original.board[1].owner = 0
  original.board[3].owner = 0
  original.board[3].mortgaged = true
  let unchanged = original
  let state = FinanceSandbox.shadowFromGame(original)
  XCTAssertEqual(state.accounts[0].ownedLots, 1)
  XCTAssertEqual(state.accounts[0].cash, original.players[0].cash)
  XCTAssertEqual(original, unchanged)
  XCTAssertEqual(state.seed, original.seed)
 }

 func testPrintedProfileValuesDoNotOverwriteClassicGame() {
  let profile = PrintedTabletopProfile()
  XCTAssertEqual(profile.salaryWhenPassingStart, 1000)
  XCTAssertEqual(profile.salaryOnExactStart, 0)
  XCTAssertEqual(profile.housesBeforeHotel, 2)
  XCTAssertEqual(profile.communalStarSupply, 8)
  XCTAssertEqual(profile.timedVictoryChoicesMinutes, [60, 90])
  XCTAssertEqual(GameFactory.make(seed: 6).players[0].cash, 1500)
 }
}