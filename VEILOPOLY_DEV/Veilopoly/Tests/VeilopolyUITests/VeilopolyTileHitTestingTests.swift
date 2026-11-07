import XCTest
@testable import VeilopolyUI

final class VeilopolyTileHitTestingTests: XCTestCase {
 func testOverlappingTouchChoosesClosestInsteadOfFirstCandidate() {
  let cells = [
   VeilopolyTileHitTarget(index: 8, x: 100, y: 50),
   VeilopolyTileHitTarget(index: 7, x: 185, y: 50)
  ]
  XCTAssertEqual(VeilopolyTileHitTesting.nearest(x: 153, y: 50, centers: cells), 7)
  XCTAssertEqual(VeilopolyTileHitTesting.nearest(x: 153, y: 50,
     centers: Array(cells.reversed())), 7)
 }
 func testIdenticalDistancesPreferStableLowestIndex() {
  let cells = [
   VeilopolyTileHitTarget(index: 13, x: 0, y: 0),
   VeilopolyTileHitTarget(index: 12, x: 80, y: 0)
  ]
  XCTAssertEqual(VeilopolyTileHitTesting.nearest(x: 40, y: 0, centers: cells), 12)
 }
 func testEmptyCenterAndOffBoardDoNotOpenRandomTitle() {
  let cells = [
   VeilopolyTileHitTarget(index: 0, x: 85, y: 85),
   VeilopolyTileHitTarget(index: 10, x: 935, y: 85),
   VeilopolyTileHitTarget(index: 20, x: 85, y: 865),
   VeilopolyTileHitTarget(index: 30, x: 935, y: 865)
  ]
  XCTAssertNil(VeilopolyTileHitTesting.nearest(x: 512, y: 470, centers: cells))
  XCTAssertNil(VeilopolyTileHitTesting.nearest(x: -400, y: 200, centers: cells))
 }
 func testBoundaryExactlyRadiusIsClickable() {
  let cells = [VeilopolyTileHitTarget(index: 3, x: 100, y: 120)]
  XCTAssertEqual(VeilopolyTileHitTesting.nearest(x: 160, y: 120, centers: cells), 3)
  XCTAssertNil(VeilopolyTileHitTesting.nearest(x: 160.1, y: 120, centers: cells))
 }
 func testRejectsInvalidTouchAndInvalidCells() {
  let cells = [
   VeilopolyTileHitTarget(index: 1, x: .nan, y: 12),
   VeilopolyTileHitTarget(index: 2, x: 200, y: 100)
  ]
  XCTAssertEqual(VeilopolyTileHitTesting.nearest(x: 200, y: 100, centers: cells), 2)
  XCTAssertNil(VeilopolyTileHitTesting.nearest(x: .infinity, y: 100, centers: cells))
  XCTAssertNil(VeilopolyTileHitTesting.nearest(x: 200, y: 100,
     centers: cells, radius: -1))
 }
}
