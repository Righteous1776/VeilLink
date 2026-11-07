import XCTest
@testable import VeilopolyEngine

final class DeclareBankruptcyTests: XCTestCase {
 func testDeclareBankruptcy() {
   var g = Fixture.game(.debt)
   g.pendingDebt = PendingDebt(player: 0, amount: 5000, creditor: 1)
   g.players[0].cash = 20; g.board[1].owner = 0
   Fixture.step(&g, .declareBankruptcy)
   XCTAssertTrue(g.players[0].bankrupt)
   XCTAssertEqual(g.board[1].owner, 1)
   XCTAssertEqual(g.players[1].cash, 1520)
 }
}
