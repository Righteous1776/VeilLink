import XCTest
@testable import VeilopolyEngine

final class AcceptTradeTests: XCTestCase {
 func testAcceptTrade() {
   var g = Fixture.game()
   g.board[1].owner = 0; g.board[6].owner = 1
   Fixture.step(&g, .proposeTrade, to: 1,
     offer: TradeTransfer(cash: 100, tiles: [1]), request: TradeTransfer(cash: 30,tiles: [6]))
   Fixture.step(&g, .acceptTrade, player: 1)
   XCTAssertEqual(g.board[1].owner, 1)
   XCTAssertEqual(g.board[6].owner, 0)
   XCTAssertEqual(g.players[0].cash, 1430)
   XCTAssertEqual(g.players[1].cash, 1570)
 }
}
