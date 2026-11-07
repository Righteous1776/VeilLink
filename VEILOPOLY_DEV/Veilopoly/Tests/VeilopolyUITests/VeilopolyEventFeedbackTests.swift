import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class VeilopolyEventFeedbackTests: XCTestCase {
 func testLatestImportantEffectWins() {
  let events = [Effect(.diceRolled, dice: [2, 4]), Effect(.bought, player: 0, tile: 1)]
  XCTAssertEqual(VeilopolyEventFeedback.summary(events), "地契入册 · 新产权已登记")
 }
 func testFinanceStatusHasMeaningfulNarration() {
  XCTAssertEqual(VeilopolyEventFeedback.summary([Effect(.bankBorrowed, player: 1)]),
                 "银号批复 · 贷款已入账，请留意到期日")
  XCTAssertEqual(VeilopolyEventFeedback.summary([Effect(.bankRepaid, player: 1)]),
                 "偿款收据 · 本笔贷款已结清")
 }
 func testNonVisualEffectsCanBeOmitted() {
  XCTAssertNil(VeilopolyEventFeedback.summary([]))
  XCTAssertNil(VeilopolyEventFeedback.summary([Effect(.bidFold, player: 1)]))
 }
 func testIvoryChanceAndFateEventAnnouncements() {
  XCTAssertEqual(VeilopolyEventFeedback.summary([
   Effect(.cardDrawn,player:0,tile:7,amount:5,deck:.chance)
  ]), "机会来函 · 阅后继续")
  XCTAssertEqual(VeilopolyEventFeedback.summary([
   Effect(.cardDrawn,player:0,tile:17,amount:20,deck:.chest)
  ]), "命运来函 · 阅后继续")
  let market = VeilopolyEventFeedback.summary([
   Effect(.stockBought,player:0,stockSymbol:"AAA",stockShares:3)
  ]) ?? ""
  XCTAssertTrue(market.contains("AAA"))
  XCTAssertTrue(market.contains("3 股") || market.contains("3股"))
 }

}
