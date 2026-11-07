import XCTest
@testable import VeilopolyEngine

final class StateBoundarySafetyTests: XCTestCase {
 func testPassingGoCannotPersistOutOfRangeCash() {
  var state = GameFactory.make(seed: 17)
  state.players[0].cash = 1_000_000_000
  state.players[0].position = 39
  state.turn.phase = .moveAnim
  state.turn.pendingSteps = 2
  let move = Move(.applyMovement, player: 0, seq: state.nextSeq)
  let beforeHash = StateDigest.hash(state)
  guard case .failure(.invalidState) = VeilopolyEngine.apply(state, VeilopolyEngine.context(state), move)
  else { return XCTFail("Overflowing salary transition was accepted") }
  XCTAssertEqual(beforeHash, StateDigest.hash(state))
 }

 func testCorruptSavingsInterestAndLoanMaturityAreRejected() {
  var state = GameFactory.make(seed: 18)
  state.turn.phase = .manage
  var ledger = IntegratedBankLedger()
  ledger.accounts[0].savings.append(.init(id: 1, feature: .demandDeposit,
                                          principal: 100, unlockPeriod: 0,
                                          payoutBasisPoints: Int.max))
  XCTAssertFalse(IntegratedBanking.validate(ledger))
  state.banking = ledger
  let move = Move(.bankWithdraw, player: 0, seq: state.nextSeq, financeID: 1)
  guard case .failure(.invalidState) = VeilopolyEngine.apply(state, VeilopolyEngine.context(state), move)
  else { return XCTFail("Unchecked savings interest was accepted") }
  ledger.accounts[0].savings = []
  ledger.accounts[0].loans.append(.init(id: 1, principal: 100,
                                       interestBasisPoints: Int.max,
                                       duePeriod: Int.max, periods: 3, totalDue: Int.max))
  XCTAssertFalse(IntegratedBanking.validate(ledger))
 }

 func testValidAccountStateStillPassesBoundedValidation() {
  var ledger = IntegratedBankLedger()
  ledger.accounts[0].savings.append(.init(id: 0, feature: .fixedDeposit,
                                          principal: 500, unlockPeriod: 2,
                                          payoutBasisPoints: 2000))
  ledger.accounts[0].loans.append(.init(id: 1, principal: 500, interestBasisPoints: 2000,
                                       duePeriod: 4, periods: 4, totalDue: 900))
  ledger.accounts[0].positions.append(.init(id: 2, feature: .managedFund,
                                           principal: 300, duePeriod: 5))
  ledger.accounts[0].borrowCount = 1
  XCTAssertTrue(IntegratedBanking.validate(ledger))
 }
}
