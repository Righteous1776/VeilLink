import XCTest
@testable import VeilopolyEngine

final class UseJailCardTests: XCTestCase {
 func testUseJailCard() {
   var g = Fixture.game(.roll)
   g.players[0].jailTurns = 3; g.players[0].chanceJailCards = 1
   Fixture.step(&g, .useJailCard, deck: .chance)
   XCTAssertEqual(g.players[0].jailTurns, 0)
   XCTAssertEqual(g.players[0].chanceJailCards, 0)
 }
}
