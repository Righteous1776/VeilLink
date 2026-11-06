import XCTest
@testable import VeilopolyEngine

final class RollDiceTests: XCTestCase {
 func testRollDice() {
   var g = Fixture.game(.roll)
   let fx = Fixture.step(&g, .rollDice)
   XCTAssertEqual(fx.first?.kind, .diceRolled)
   XCTAssertEqual(g.rngCounter, 32)
   XCTAssertTrue([Phase.moveAnim, .manage].contains(g.turn.phase))
 }
}
