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
 func testMaximizedBoardPreservesFullSquareOnLandscapePhone() {
  let oldWidth = 844.0 - 20 - 12 - VeilopolyLandscapeLayout.sidebarWidth(for: 844)
  let legacy = VeilopolyLandscapeLayout.boardSize(availableWidth: oldWidth, availableHeight: 390 - 12)
  let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 844, availableHeight: 390)
  XCTAssertGreaterThan(board.width, legacy.width)
  XCTAssertLessThanOrEqual(board.width, 844 - 12)
  XCTAssertLessThanOrEqual(board.height, 390 - 8)
  XCTAssertEqual(board.width / board.height, VeilopolyLandscapeLayout.boardAspect, accuracy: 0.0001)
 }

 func testMaximizedBoardRespectsIPadViewportAndNeverConsumesSidebarWidth() {
  let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 1180, availableHeight: 820)
  XCTAssertEqual(board.height, 812, accuracy: 0.001)
  XCTAssertEqual(board.width, 812 * VeilopolyLandscapeLayout.boardAspect, accuracy: 0.001)
  XCTAssertLessThan(board.width, 1180 - 12)
 }

 func testFloatingDrawerIsTouchSizedButNotPartOfBoardMeasurement() {
  XCTAssertEqual(VeilopolyLandscapeLayout.overlayDrawerWidth(for: 844), 371.36, accuracy: 0.01)
  XCTAssertEqual(VeilopolyLandscapeLayout.overlayDrawerWidth(for: 568), 292, accuracy: 0.001)
  XCTAssertEqual(VeilopolyLandscapeLayout.overlayDrawerHeight(for: 390), 326, accuracy: 0.001)
  // A permanent drawer would shrink this iPad's complete 40-tile board;
  // the floating drawer must not participate in the aspect-fit calculation.
  let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 1180, availableHeight: 820)
  let artificiallyReserved = VeilopolyLandscapeLayout.boardSize(
   availableWidth: 1180 - VeilopolyLandscapeLayout.overlayDrawerWidth(for: 1180),
   availableHeight: 820 - 2 * VeilopolyLandscapeLayout.boardVerticalInset)
  XCTAssertGreaterThan(board.width, artificiallyReserved.width)
  XCTAssertGreaterThanOrEqual(VeilopolyLandscapeLayout.capsuleButtonWidth, 44)
 }

 func testTinyOrInvalidViewportReturnsSafeNonNegativeDimensions() {
  let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 5, availableHeight: 4)
  XCTAssertEqual(board.width, 0)
  XCTAssertEqual(board.height, 0)
  XCTAssertEqual(VeilopolyLandscapeLayout.overlayDrawerWidth(for: -5), 0)
  XCTAssertEqual(VeilopolyLandscapeLayout.overlayDrawerHeight(for: -5), 0)
 }

}
