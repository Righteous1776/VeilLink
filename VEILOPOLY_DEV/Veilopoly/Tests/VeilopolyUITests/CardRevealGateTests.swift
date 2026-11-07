import XCTest
@testable import VeilopolyUI
final class CardRevealGateTests: XCTestCase {
 func testSceneAckDoesNotSkipReadableCard() {
  var gate = CardRevealGate(); gate.present()
  XCTAssertFalse(gate.animationDidComplete())
  XCTAssertTrue(gate.isPresented)
  XCTAssertEqual(gate.dismiss(), .advanceQueue)
 }
 func testEarlyDismissFastForwardsThenAcknowledgesOnce() {
  var gate = CardRevealGate(); gate.present()
  XCTAssertEqual(gate.dismiss(), .finishAnimation)
  XCTAssertTrue(gate.animationDidComplete())
  XCTAssertEqual(gate.dismiss(), .none)
 }
 func testRepeatCardsResetRevealState() {
  var gate = CardRevealGate(); gate.present()
  _ = gate.animationDidComplete(); gate.present()
  XCTAssertFalse(gate.animationCompleted)
  XCTAssertEqual(gate.dismiss(), .finishAnimation)
 }
 func testNoCardDoesNotBlockRegularAck() {
  var gate = CardRevealGate()
  XCTAssertTrue(gate.animationDidComplete())
  XCTAssertEqual(gate.dismiss(), .none)
 }
 func testResetDiscardsPendingReveal() {
  var gate = CardRevealGate(); gate.present()
  _ = gate.animationDidComplete(); gate.reset()
  XCTAssertFalse(gate.isPresented)
  XCTAssertFalse(gate.animationCompleted)
 }
}
