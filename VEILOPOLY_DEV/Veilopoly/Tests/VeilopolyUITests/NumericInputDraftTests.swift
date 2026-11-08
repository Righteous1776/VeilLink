import XCTest
@testable import VeilopolyUI

final class NumericInputDraftTests: XCTestCase {
 func testAmountEditingAndClearBackspaceDoNotOverflow() {
  var draft = VeilopolyNumericInputDraft(text: "0", bounds: 0...1_000_000_000)
  XCTAssertTrue(draft.append(1))
  for _ in 0..<9 { XCTAssertTrue(draft.append(0)) }
  XCTAssertEqual(draft.value, 1_000_000_000)
  XCTAssertFalse(draft.append(1))
  XCTAssertEqual(draft.text, "1000000000")
  draft.backspace()
  XCTAssertEqual(draft.value, 100_000_000)
  draft.clear()
  draft.backspace()
  XCTAssertNil(draft.value)
  XCTAssertFalse(draft.append(-1))
  XCTAssertFalse(draft.append(10))
 }

 func testLoanPeriodsAllowPartialEntryButOnlyConfirmWithinBounds() {
  var draft = VeilopolyNumericInputDraft(text: "", bounds: 1...12)
  XCTAssertTrue(draft.append(0))
  XCTAssertNil(draft.value)
  XCTAssertTrue(draft.append(1))
  XCTAssertEqual(draft.value, 1)
  XCTAssertFalse(draft.append(3))
  XCTAssertEqual(draft.text, "1")
  XCTAssertTrue(draft.append(2))
  XCTAssertEqual(draft.value, 12)
 }

 func testStockQuantityLimitAndInvalidInitialInput() {
  var draft = VeilopolyNumericInputDraft(text: "9999", bounds: 1...10_000)
  XCTAssertFalse(draft.append(9))
  XCTAssertEqual(draft.value, 9999)
  for invalid in ["", "-1", "+1", "1.5", " 1", "１", "١", String(repeating: "9", count: 100)] {
   XCTAssertNil(VeilopolyNumericInputDraft(text: invalid, bounds: 0...Int.max).value)
  }
  var invalid = VeilopolyNumericInputDraft(text: "bad", bounds: 1...10_000)
  XCTAssertFalse(invalid.append(1))
  invalid.clear()
  XCTAssertTrue(invalid.append(2))
  XCTAssertEqual(invalid.value, 2)
 }

 func testEditingIsDetachedFromOriginalUntilCallerConfirms() {
  let original = "200"
  var draft = VeilopolyNumericInputDraft(text: original, bounds: 0...1_000_000_000)
  draft.clear()
  XCTAssertTrue(draft.append(5))
  XCTAssertEqual(draft.value, 5)
  XCTAssertEqual(original, "200", "Cancel can discard the draft without changing the bound field")
 }
}
