import Foundation
import XCTest
@testable import VeilopolyUI

final class VeilopolyCompleteManualResourceTests: XCTestCase {
 func testExhaustiveManualResourceIsEmbeddedAndSearchable() {
  let markdown = VeilopolyCompleteManual.markdown
  XCTAssertTrue(markdown.contains("VLP-MANUAL-V5-R1"))
  XCTAssertTrue(markdown.contains("¥2,100,000"))
  XCTAssertTrue(markdown.contains("32 张"))
  XCTAssertTrue(markdown.contains("未验收"))
  XCTAssertEqual(VeilopolyCompleteManual.minimumIOSMajorVersion, 15)
  XCTAssertEqual(VeilopolyCompleteManual.sections.count, 28)
  XCTAssertFalse(VeilopolyCompleteManual.filtered("破产").isEmpty)
  XCTAssertFalse(VeilopolyCompleteManual.filtered("股票").isEmpty)
  XCTAssertTrue(VeilopolyCompleteManual.filtered("完全不存在的检索字符串9493921").isEmpty)
 }

 func testEveryBoardCellAndCardIndexHasAnEntry() {
  let text = VeilopolyCompleteManual.markdown
  for index in 0..<40 {
   XCTAssertTrue(text.contains("| \(index) |"), "board slot \(index)")
  }
  for index in 0..<32 {
   let token = String(format: "| #%02d |", index)
   XCTAssertTrue(text.contains(token), "card \(index)")
  }
 }
 func testManualParsingDoesNotDependOnGameStateOrNetworking() {
  let first = VeilopolyCompleteManual.sections
  let second = VeilopolyCompleteManual.sections
  XCTAssertEqual(first, second)
  XCTAssertTrue(first.contains { $0.heading.contains("货币") })
  XCTAssertEqual(VeilopolyCompleteManual.filtered("   ").count, first.count)
 }
}
