import XCTest
@testable import VeilopolyEngine

final class BuildHouseTests: XCTestCase {
 func testBuildHouse() {
   var g = Fixture.ownedSet()
   Fixture.step(&g, .buildHouse, tile: 1)
   XCTAssertEqual(g.board[1].houses, 1)
   XCTAssertEqual(g.bank.houses, 31)
   Fixture.fails(g, Move(.buildHouse, player: 0, seq: g.nextSeq, tile: 1), .buildUneven)
 }
}
