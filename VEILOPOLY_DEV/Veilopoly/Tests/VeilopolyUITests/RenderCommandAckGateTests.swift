import XCTest
@testable import VeilopolyUI

final class RenderCommandAckGateTests: XCTestCase {
 func testEachCommandCanAcknowledgeExactlyOnce() {
  var gate = RenderCommandAckGate()
  let first = gate.begin()
  XCTAssertEqual(gate.pending, first)
  XCTAssertTrue(gate.acknowledge(first))
  XCTAssertNil(gate.pending)
  XCTAssertFalse(gate.acknowledge(first))
 }

 func testLateCallbackCannotAdvanceTheNextCommand() {
  var gate = RenderCommandAckGate()
  let old = gate.begin()
  let next = gate.begin()
  XCTAssertNotEqual(old, next)
  XCTAssertFalse(gate.acknowledge(old))
  XCTAssertEqual(gate.pending, next)
  XCTAssertTrue(gate.acknowledge(next))
 }

 func testSkipConsumesCurrentCommandAndDropsLateNaturalCompletion() {
  var gate = RenderCommandAckGate()
  let command = gate.begin()
  XCTAssertTrue(gate.acknowledge(command))  // skip
  XCTAssertFalse(gate.acknowledge(command)) // SpriteKit completion arrives late
  let next = gate.begin()
  XCTAssertNotEqual(command, next)
  XCTAssertTrue(gate.acknowledge(next))
 }

 func testCancelDoesNotAcknowledgeAndNextCommandStillWorks() {
  var gate = RenderCommandAckGate()
  let abandoned = gate.begin()
  gate.cancel()
  XCTAssertFalse(gate.acknowledge(abandoned))
  XCTAssertNil(gate.pending)
  let new = gate.begin()
  XCTAssertFalse(gate.acknowledge(abandoned))
  XCTAssertTrue(gate.acknowledge(new))
 }

 func testNeverStartedCommandCannotAcknowledge() {
  var gate = RenderCommandAckGate()
  XCTAssertFalse(gate.acknowledge(0))
  XCTAssertFalse(gate.acknowledge(1))
 }
}
