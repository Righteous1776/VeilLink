import XCTest
@testable import VeilopolyUI

final class PanelWorkspaceTests: XCTestCase {
 func testDefaultCollapsedAndSeparatePlacements() {
  let state = VeilopolyPanelWorkspace()
  XCTAssertFalse(state.isExpanded)
  XCTAssertNil(state.decision)
  XCTAssertEqual(state.panelAnchor, .topRight)
  XCTAssertEqual(state.chipAnchor, .bottomRight)
 }

 func testSuspendKeepsPlacementAndPendingDecision() {
  var state = VeilopolyPanelWorkspace()
  let decision = VeilopolyPanelDecision(seed: 9, actor: 0, phase: "auction", subject: 3)
  state.panelAnchor = .init(x: 0.2, y: 0.8)
  state.observe(decision)
  XCTAssertTrue(state.isExpanded)
  state.suspend()
  state.observe(decision) // Includes re-render after a stock/ACK refresh.
  XCTAssertFalse(state.isExpanded)
  XCTAssertEqual(state.decision, decision)
  XCTAssertEqual(state.panelAnchor, .init(x: 0.2, y: 0.8))
  state.open()
  XCTAssertTrue(state.isExpanded)
 }

 func testNewDecisionReopensButSameDecisionNeverDoes() {
  var state = VeilopolyPanelWorkspace()
  for decision in [
   VeilopolyPanelDecision(seed: 9, actor: 0, phase: "tileResolve", subject: 1),
   .init(seed: 9, actor: 0, phase: "tileResolve", subject: 3),
   .init(seed: 9, actor: 1, phase: "auction", subject: 3),
   .init(seed: 10, actor: 1, phase: "auction", subject: 3)
  ] {
   state.observe(decision)
   XCTAssertTrue(state.isExpanded)
   state.suspend()
   state.observe(decision)
   XCTAssertFalse(state.isExpanded)
  }
  state.observe(nil)
  XCTAssertNil(state.decision)
  state.observe(.init(seed: 10, actor: 1, phase: "auction", subject: 3))
  XCTAssertTrue(state.isExpanded)
 }

 func testResetPlacementDoesNotDropTheCurrentDecisionOrOpenState() {
  var state = VeilopolyPanelWorkspace()
  state.observe(.init(seed: 3, actor: 2, phase: "trade"))
  state.panelAnchor = .init(x: 0, y: 1)
  state.chipAnchor = .init(x: 0.5, y: 0.5)
  state.resetPlacement()
  XCTAssertEqual(state.panelAnchor, .topRight)
  XCTAssertEqual(state.chipAnchor, .bottomRight)
  XCTAssertNotNil(state.decision)
  XCTAssertTrue(state.isExpanded)
  state.resetSession()
  XCTAssertEqual(state, VeilopolyPanelWorkspace())
 }

 func testExtremeDragAlwaysStaysBelowCapsuleAndInsideViewport() {
  for (width, height) in [(844.0, 390.0), (852, 393), (1180, 820), (568, 320), (724, 342)] {
   let layout = VeilopolyPanelLayout(width: width, height: height)
   for surface in [VeilopolyPanelLayout.Surface.panel, .chip] {
    for dx in [-10000.0, 0, 10000] {
     for dy in [-10000.0, 0, 10000] {
      let frame = layout.frame(for: surface, anchor: .bottomRight, dx: dx, dy: dy)
      XCTAssertGreaterThanOrEqual(frame.minX, 6)
      XCTAssertGreaterThanOrEqual(frame.minY, 54)
      XCTAssertLessThanOrEqual(frame.maxX, width - 6)
      XCTAssertLessThanOrEqual(frame.maxY, height - 10)
      XCTAssertGreaterThanOrEqual(frame.width, 44)
      XCTAssertGreaterThanOrEqual(frame.height, 44)
     }
    }
   }
  }
 }

 func testCommittedDragMatchesLiveFrameWithoutAccumulatingTranslation() {
  let layout = VeilopolyPanelLayout(width: 1180, height: 820)
  let anchor = VeilopolyPanelAnchor(x: 0.8, y: 0.3)
  for surface in [VeilopolyPanelLayout.Surface.panel, .chip] {
   let actual = layout.frame(for: surface, anchor: anchor, dx: -120, dy: 90)
   let next = layout.moved(anchor, surface: surface, dx: -120, dy: 90)
   let committed = layout.frame(for: surface, anchor: next)
   XCTAssertEqual(actual.minX, committed.minX, accuracy: 0.00001)
   XCTAssertEqual(actual.minY, committed.minY, accuracy: 0.00001)
  }
 }

 func testNormalizedPlacementSurvivesSafeAreaAndWindowResize() {
  let tablet = VeilopolyPanelLayout(width: 1180, height: 820)
  let phone = VeilopolyPanelLayout(width: 720, height: 320)
  let anchor = tablet.moved(.topRight, surface: .panel, dx: -130, dy: 130)
  let frame = phone.frame(for: .panel, anchor: anchor)
  XCTAssertGreaterThanOrEqual(frame.minX, 6)
  XCTAssertLessThanOrEqual(frame.maxX, 714)
  XCTAssertGreaterThanOrEqual(frame.minY, 54)
  XCTAssertLessThanOrEqual(frame.maxY, 310)
  // No travel in this short viewport must not discard the preferred position.
  XCTAssertEqual(phone.moved(anchor, surface: .panel, dx: 0, dy: 0).y, anchor.y)
 }

 func testInvalidGeometryAndCoordinatesRemainFiniteAndNonnegative() {
  for (w, h) in [(0.0, 0.0), (-1, -1), (5, 4), (.nan, .infinity)] {
   let layout = VeilopolyPanelLayout(width: w, height: h)
   for surface in [VeilopolyPanelLayout.Surface.panel, .chip] {
    let frame = layout.frame(for: surface, anchor: .init(x: .nan, y: .infinity), dx: .nan, dy: .infinity)
    XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite)
    XCTAssertGreaterThanOrEqual(frame.width, 0)
    XCTAssertGreaterThanOrEqual(frame.height, 0)
    XCTAssertLessThanOrEqual(frame.maxX, layout.width)
    XCTAssertLessThanOrEqual(frame.maxY, layout.height)
   }
  }
 }

 func testDraggingOrSuspendingNeverChangesBoardGeometry() {
  let before = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 1180, availableHeight: 820)
  var state = VeilopolyPanelWorkspace()
  state.open()
  state.panelAnchor = VeilopolyPanelLayout(width: 1180, height: 820)
   .moved(.topRight, surface: .panel, dx: -300, dy: 100)
  state.suspend()
  let after = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: 1180, availableHeight: 820)
  XCTAssertEqual(before.width, after.width)
  XCTAssertEqual(before.height, after.height)
 }

 func testCompactToolbarAndPinnedActionsLeaveUsableScrollArea() {
  for (w, h) in [(568.0, 320.0), (724, 342), (844, 390), (852, 393), (1180, 820)] {
   let panel = VeilopolyPanelLayout(width: w, height: h).frame(for: .panel, anchor: .topRight)
   // Source layout: 10pt padding, 3x44 toolbar tools + three 4pt gaps.
   // The drag title needs >=80pt; no tool may shrink to make it fit.
   XCTAssertGreaterThanOrEqual(panel.width - 20 - 3 * 44 - 3 * 4, 80)
   // Worst case: toolbar + management tabs + end-turn = 3x44, 3x8 gaps.
   // Network details and account rows belong INSIDE this scroll area.
   XCTAssertGreaterThanOrEqual(panel.height - 20 - 3 * 44 - 3 * 8, 80)
  }
 }

 func testDefaultPhonePanelDoesNotCoverTheBoardAndTopStripIsAlwaysClear() {
  for (w, h) in [(844.0, 390.0), (852, 393), (724, 342)] {
   let panel = VeilopolyPanelLayout(width: w, height: h).frame(for: .panel, anchor: .topRight)
   let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: w, availableHeight: h)
   XCTAssertGreaterThan(panel.minX, board.width + VeilopolyLandscapeLayout.boardHorizontalInset)
   XCTAssertGreaterThan(panel.minY, 5 + VeilopolyLandscapeLayout.capsuleTouchHeight)
  }
 }
}
