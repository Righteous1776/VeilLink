import XCTest
@testable import VeilopolyEngine

final class ApplyMovementTests: XCTestCase {
 func testApplyMovement() {
   var g = Fixture.game(.moveAnim)
   g.players[0].position = 38; g.turn.pendingSteps = 4
   let fx = Fixture.step(&g, .applyMovement)
   XCTAssertEqual(g.players[0].position, 2)
   XCTAssertEqual(g.players[0].cash, 1700)
   XCTAssertTrue(fx.contains { $0.kind == .passedGo })
 }
}
