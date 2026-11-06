import XCTest
@testable import VeilopolyEngine

final class ProposeTradeTests: XCTestCase {
 func testProposeTrade() {
   var g = Fixture.game()
   g.board[1].owner = 0; g.board[6].owner = 1
   Fixture.step(&g, .proposeTrade, to: 1,
     offer: TradeTransfer(cash: 100, tiles: [1]), request: TradeTransfer(tiles: [6]))
   XCTAssertEqual(g.turn.phase, .trade)
   XCTAssertEqual(g.trade?.from, 0)
 }
}
