import XCTest
@testable import VeilopolyUI

final class TokenFormationTests: XCTestCase {
 func testFourPlayerPositionsAreStableAndDistinct() throws {
  let offsets = try (0..<4).map { try XCTUnwrap(VeilopolyTokenFormation.offset(player: $0)) }
  XCTAssertEqual(Set(offsets.map { "\($0.x),\($0.y)" }).count, 4)
  XCTAssertEqual(offsets, (0..<4).compactMap(VeilopolyTokenFormation.offset(player:)))
 }
 func testFourTokensStayWithinTileBounds() throws {
  let half = VeilopolyTokenFormation.tokenSize / 2
  for player in 0..<4 {
   let offset = try XCTUnwrap(VeilopolyTokenFormation.offset(player: player))
   XCTAssertLessThanOrEqual(abs(offset.x) + half, 81 / 2)
   XCTAssertLessThanOrEqual(abs(offset.y) + half, 73 / 2)
  }
 }
 func testInvalidPlayerHasNoPlacement() {
  XCTAssertNil(VeilopolyTokenFormation.offset(player: -1))
  XCTAssertNil(VeilopolyTokenFormation.offset(player: 4))
 }
}
