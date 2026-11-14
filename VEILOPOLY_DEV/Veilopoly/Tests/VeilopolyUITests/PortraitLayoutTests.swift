import XCTest
@testable import VeilopolyUI

final class PortraitLayoutTests: XCTestCase {
 func testIPhone7PortraitSplit() {
  let split = VeilopolyPortraitLayout.allocate(availableWidth: 375, availableHeight: 667)
  XCTAssertGreaterThan(split.boardHeight, 0)
  XCTAssertLessThanOrEqual(split.boardHeight, 333.5)
  XCTAssertGreaterThanOrEqual(split.workspaceHeight, 333.5)
  XCTAssertEqual(split.boardHeight + split.workspaceHeight, 667, accuracy: 0.001)
 }
 func testPortraitSizesNeverCropAllocation() {
  for (w, h) in [(375.0, 667.0), (390.0, 844.0), (820.0, 1180.0)] {
   let split = VeilopolyPortraitLayout.allocate(availableWidth: w, availableHeight: h)
   XCTAssertGreaterThan(split.boardHeight, 0)
   XCTAssertLessThanOrEqual(split.boardHeight, h / 2)
   XCTAssertEqual(split.boardHeight + split.workspaceHeight, h, accuracy: 0.001)
  }
 }
 func testBadViewportIsHarmless() {
  let split = VeilopolyPortraitLayout.allocate(availableWidth: -1, availableHeight: -2)
  XCTAssertEqual(split.boardHeight, 0)
  XCTAssertEqual(split.workspaceHeight, 0)
 }
}
