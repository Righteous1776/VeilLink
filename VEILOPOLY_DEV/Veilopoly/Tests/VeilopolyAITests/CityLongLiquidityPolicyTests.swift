import XCTest
import VeilopolyEngine
@testable import VeilopolyAI

final class CityLongLiquidityPolicyTests: XCTestCase {
 func testCityAIWillNotBuyLastExpensiveLotWithAlmostNoReserve() {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 91311, humanCount: 0)
  g.turn.phase = .tileResolve
  g.turn.pendingPurchase = 39
  g.players[0].cash = 1400
  let move = VeilopolyAI.decide(g, VeilopolyEngine.context(g), me: 0, level: .balanced)
  XCTAssertEqual(move.type, .startAuction)
  XCTAssertEqual(move.tile, 39)
 }
 func testLiquidityFloorDoesNotGrowForeverAndBlockAllPurchases() {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 91312, humanCount: 0)
  g.banking?.completedTurns = 70
  g.turn.phase = .tileResolve
  g.turn.pendingPurchase = 39
  let move = VeilopolyAI.decide(g, VeilopolyEngine.context(g), me: 0, level: .balanced)
  XCTAssertEqual(move.type, .buyProperty)
  XCTAssertEqual(move.tile, 39)
 }
 func testLegacyAIReservePolicyNotRewrittenByLongMode() {
  var g = GameFactory.make(seed: 91313, humanCount: 0)
  g.turn.phase = .tileResolve
  g.turn.pendingPurchase = 39
  g.players[0].cash = 1400
  let move = VeilopolyAI.decide(g, VeilopolyEngine.context(g), me: 0, level: .balanced)
  XCTAssertEqual(move.type, .buyProperty)
 }
}
