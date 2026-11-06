import XCTest
@testable import VeilopolyUI

final class LandscapeLayoutTests: XCTestCase {
 func testLandscapeDetectionDoesNotFakeRotation() {
  XCTAssertTrue(VeilopolyLandscapeLayout.isLandscape(width: 844, height: 390))
  XCTAssertFalse(VeilopolyLandscapeLayout.isLandscape(width: 390, height: 844))
  XCTAssertFalse(VeilopolyLandscapeLayout.isLandscape(width: 400, height: 400))
 }

 func testBoardFitsLandscapePhoneViewport() {
  let board = VeilopolyLandscapeLayout.boardSize(availableWidth: 430, availableHeight: 320)
  XCTAssertLessThanOrEqual(board.width, 430)
  XCTAssertLessThanOrEqual(board.height, 320)
  XCTAssertEqual(board.width / board.height, VeilopolyLandscapeLayout.boardAspect, accuracy: 0.0001)
 }

 func testBoardFitsIPadViewportWithoutCropping() {
  let board = VeilopolyLandscapeLayout.boardSize(availableWidth: 800, availableHeight: 680)
  XCTAssertLessThanOrEqual(board.width, 800)
  XCTAssertLessThanOrEqual(board.height, 680)
  XCTAssertEqual(board.width / board.height, VeilopolyLandscapeLayout.boardAspect, accuracy: 0.0001)
 }

 func testPhoneSidebarAndCapsuleTouchTargets() {
  XCTAssertEqual(VeilopolyLandscapeLayout.sidebarWidth(for: 844), 337.6, accuracy: 0.01)
  XCTAssertEqual(VeilopolyLandscapeLayout.sidebarWidth(for: 568), 285, accuracy: 0.01)
  XCTAssertGreaterThanOrEqual(VeilopolyLandscapeLayout.capsuleButtonWidth, 44)
  XCTAssertGreaterThanOrEqual(VeilopolyLandscapeLayout.capsuleTouchHeight, 44)
 }

 func testZeroViewportCannotCreateNegativeBoard() {
  let board = VeilopolyLandscapeLayout.boardSize(availableWidth: -1, availableHeight: 100)
  XCTAssertEqual(board.width, 0)
  XCTAssertEqual(board.height, 0)
 }
}
