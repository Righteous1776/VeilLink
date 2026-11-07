import XCTest
@testable import VeilopolyEngine

final class ResolveTileTests: XCTestCase {
 func testResolveTile() {
   var g = Fixture.game(.tileResolve)
   g.players[0].position = 4
   let fx = Fixture.step(&g, .resolveTile)
   XCTAssertEqual(g.players[0].cash, 1300)
   XCTAssertEqual(g.turn.phase, .manage)
   XCTAssertTrue(fx.contains { $0.kind == .cashChanged })
 }
}
