import XCTest
@testable import VeilopolyEngine

final class PayBailTests: XCTestCase {
 func testPayBail() {
   var g = Fixture.game(.roll)
   g.players[0].jailTurns = 3
   Fixture.step(&g, .payBail)
   XCTAssertEqual(g.players[0].cash, 1450)
   XCTAssertEqual(g.players[0].jailTurns, 0)
 }
}
