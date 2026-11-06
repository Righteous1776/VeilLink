import XCTest
@testable import VeilopolyEngine

final class CanonicalFinanceHashTests: XCTestCase {
 func testFinancePolicyDictionaryInsertionOrderCannotChangeStateHash() throws {
  var first = FinanceSandboxPolicy()
  first.payouts[.managedFund] = [0, 1000, 2500, 5000, 15000, 20000]
  first.payouts[.stockSimulation] = [0, 1000, 2500, 5000, 10000, 14000]
  first.payouts[.ventureSimulation] = [0, 0, 1000, 5000, 15000, 20000]
  var reversed = FinanceSandboxPolicy()
  reversed.payouts[.ventureSimulation] = [0, 0, 1000, 5000, 15000, 20000]
  reversed.payouts[.stockSimulation] = [0, 1000, 2500, 5000, 10000, 14000]
  reversed.payouts[.managedFund] = [0, 1000, 2500, 5000, 15000, 20000]
  let factory = GameFactory.make(seed: 4862, humanCount: 0)
  let a = try XCTUnwrap(IntegratedBanking.configured(factory, terms: first))
  let b = try XCTUnwrap(IntegratedBanking.configured(factory, terms: reversed))
  XCTAssertEqual(a, b)
  XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
  let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
  let c = try JSONDecoder().decode(GameState.self, from: enc.encode(a))
  XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(c))
  XCTAssertNotEqual(StateDigest.hash(a), "ENCODING_ERROR")
 }

 func testRejectedFinanceActionIsHashStableWithSeededPolicy() throws {
  var policy = FinanceSandboxPolicy()
  policy.payouts[.stockSimulation] = [0, 1000, 2000, 3000, 4000, 5000]
  var g = GameFactory.make(seed: 591, humanCount: 0)
  g = try XCTUnwrap(IntegratedBanking.configured(g, terms: policy))
  g.turn.phase = .manage
  let initialHash = StateDigest.hash(g)
  let invalid = Move(.bankInvest, player: 0, seq: g.nextSeq, amount: 2_000,
                     financeProduct: .stockSimulation)
  switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), invalid) {
  case .success: XCTFail("insufficient cash must reject")
  case .failure(let error): XCTAssertEqual(error, .noCash)
  }
  XCTAssertEqual(g.nextSeq, 0)
  XCTAssertEqual(StateDigest.hash(g), initialHash)
 }
}
