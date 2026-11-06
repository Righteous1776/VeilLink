import XCTest
@testable import VeilopolyEngine

final class RejectTradeTests: XCTestCase {
 func testRejectTrade() {
   var g = Fixture.game()
   Fixture.step(&g, .proposeTrade, to: 1, offer: TradeTransfer(), request: TradeTransfer())
   Fixture.step(&g, .rejectTrade, player: 1)
   XCTAssertNil(g.trade)
   XCTAssertEqual(g.turn.phase, .manage)
 }
}
