import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class VeilopolyEventFeedbackTests: XCTestCase {
 func testLatestImportantEffectWins() {
  let events = [Effect(.diceRolled, dice: [2, 4]), Effect(.bought, player: 0, tile: 1)]
  XCTAssertEqual(VeilopolyEventFeedback.summary(events), "购买成功 · 地产已登记")
 }
 func testFinanceStatusHasMeaningfulNarration() {
  XCTAssertEqual(VeilopolyEventFeedback.summary([Effect(.bankBorrowed, player: 1)]),
                 "贷款申请成功 · 请留意到期日")
  XCTAssertEqual(VeilopolyEventFeedback.summary([Effect(.bankRepaid, player: 1)]),
                 "贷款已偿还")
 }
 func testNonVisualEffectsCanBeOmitted() {
  XCTAssertNil(VeilopolyEventFeedback.summary([]))
  XCTAssertNil(VeilopolyEventFeedback.summary([Effect(.bidFold, player: 1)]))
 }
}
