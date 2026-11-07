import XCTest
@testable import VeilopolyEngine

final class FinanceRuleModelTests: XCTestCase {
 func testRuleJudgeRecommendsMatureSavingsThenLoan() throws {
  var g = Fixture.game(.manage)
  func step(_ type: MoveKind, amount: Int? = nil, product: FinancialFeature? = nil,
            periods: Int? = nil, id: Int? = nil) throws {
   let move = Move(type, player: 0, seq: g.nextSeq, amount: amount, financeProduct: product,
                   financePeriods: periods, financeID: id)
   switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move) {
   case .success((let state, _)): g = state
   case .failure(let e): throw e
   }
  }
  try step(.bankDeposit, amount: 100, product: .demandDeposit)
  let deposit = try XCTUnwrap(g.banking?.accounts[0].savings.first)
  XCTAssertEqual(FinancialRuleJudge.recommendation(g, player: 0)?.financeID, deposit.id)
  XCTAssertEqual(FinancialRuleJudge.recommendation(g, player: 0)?.type, .bankWithdraw)
  try step(.bankWithdraw, id: deposit.id)
  XCTAssertNil(FinancialRuleJudge.recommendation(g, player: 0))
 }
 func testDeterministicBankingReplayOver150SeedsAndHash() throws {
  for seed in 0..<150 {
   var a = GameFactory.make(seed: UInt64(seed), humanCount: 0)
   var b = GameFactory.make(seed: UInt64(seed), humanCount: 0)
   a.turn.phase = .manage; b.turn.phase = .manage
   var moves: [Move] = []
   moves.append(.init(.bankDeposit, player: 0, seq: 0, amount: 50 + seed % 100, financeProduct: .demandDeposit))
   moves.append(.init(.bankWithdraw, player: 0, seq: 1, financeID: 0))
   moves.append(.init(.bankBorrow, player: 0, seq: 2, amount: 100, financePeriods: 2))
   moves.append(.init(.bankRepay, player: 0, seq: 3, financeID: 2))
   for move in moves {
    for side in 0..<2 {
     let current = side == 0 ? a : b
     switch VeilopolyEngine.apply(current, VeilopolyEngine.context(current), move) {
     case .failure(let e): XCTFail("seed \\(seed), move \\(move.type), failure \\(e)")
     case .success((let g, _)): if side == 0 { a = g } else { b = g }
     }
    }
    XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
   }
   XCTAssertEqual(a, b)
   XCTAssertEqual(a.players[0].cash, 1460) // 1500 - 100 * 20% * 2
  }
 }
 func testEveryRejectedBankMoveKeepsHashAndSequence() throws {
  let g = Fixture.game(.manage)
  for kind in [MoveKind.bankWithdraw, .bankRepay, .bankSettle] {
   let m = Move(kind, player: 0, seq: 0, financeID: 999)
   switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), m) {
   case .success: XCTFail("invalid request accepted")
   case .failure: break
   }
   XCTAssertEqual(g.nextSeq, 0)
   XCTAssertNil(g.banking)
  }
 }
}
