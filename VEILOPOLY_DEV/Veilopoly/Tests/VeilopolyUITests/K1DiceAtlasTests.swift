import XCTest
@testable import VeilopolyUI

final class K1DiceAtlasTests: XCTestCase {
 func testAllSixAtlasFramesAreDistinctAndWithinImage() throws {
  let frames = try (1...6).map { try XCTUnwrap(VeilopolyDiceAtlasMap.frame(face: $0)) }
  XCTAssertEqual(Set(frames.map { "\($0.x):\($0.y)" }).count, 6)
  for frame in frames {
   XCTAssertGreaterThanOrEqual(frame.x, 0)
   XCTAssertGreaterThanOrEqual(frame.y, 0)
   XCTAssertLessThanOrEqual(frame.x+frame.width, 1)
   XCTAssertLessThanOrEqual(frame.y+frame.height, 1)
   XCTAssertEqual(frame.width, 0.25)
   XCTAssertEqual(frame.height, 0.5)
  }
 }

 func testTopLeftKimiXMLCoordinatesFlipToBottomOrigin() throws {
  let face1 = try XCTUnwrap(VeilopolyDiceAtlasMap.frame(face: 1))
  let face3 = try XCTUnwrap(VeilopolyDiceAtlasMap.frame(face: 3))
  XCTAssertEqual(face1.x, 0.25)
  XCTAssertEqual(face1.y, 0.5)
  XCTAssertEqual(face3.y, 0.0)
  XCTAssertNil(VeilopolyDiceAtlasMap.frame(face: 0))
  XCTAssertNil(VeilopolyDiceAtlasMap.frame(face: 7))
 }
 func testActualK1ResourcesAreBundledAndMetadataPointsToImage() {
  XCTAssertTrue(VeilopolyDiceAtlasMap.hasK1RuntimeResources(),
                "K1 image/audio resources or corrected XML metadata missing from SwiftPM bundle")
 }

}
