import XCTest
@testable import VeilopolyEngine

final class EndTurnTests: XCTestCase {
 func testEndTurn() {
   var g = Fixture.game()
   Fixture.step(&g, .endTurn)
   XCTAssertEqual(g.turn.player, 1)
   XCTAssertEqual(g.turn.phase, .roll)
 }
}
