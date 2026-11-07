import XCTest
@testable import VeilopolyEngine

final class CounterTradeTests: XCTestCase {
 func testCounterTrade() {
   var g = Fixture.game()
   Fixture.step(&g, .proposeTrade, to: 1, offer: TradeTransfer(), request: TradeTransfer())
   Fixture.step(&g, .counterTrade, player: 1, offer: TradeTransfer(cash: 25), request: TradeTransfer())
   XCTAssertEqual(g.trade?.from, 1)
   XCTAssertEqual(g.trade?.to, 0)
 }
}
