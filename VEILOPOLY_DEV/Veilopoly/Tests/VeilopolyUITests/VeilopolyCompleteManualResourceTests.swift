import Foundation
import XCTest
@testable import VeilopolyUI

final class VeilopolyCompleteManualResourceTests: XCTestCase {
 func testExhaustiveManualResourceIsEmbeddedAndSearchable() {
  let markdown = VeilopolyMarkdownManual.markdown
  XCTAssertTrue(markdown.contains("VLP-MANUAL-V5-R1"))
  XCTAssertTrue(markdown.contains("¥2,100,000"))
  XCTAssertTrue(markdown.contains("32 张"))
  XCTAssertTrue(markdown.contains("未验收"))
  XCTAssertEqual(VeilopolyMarkdownManual.minimumIOSMajorVersion, 15)
  XCTAssertEqual(VeilopolyMarkdownManual.sections.count, 28)
  XCTAssertFalse(VeilopolyMarkdownManual.filtered("破产").isEmpty)
  XCTAssertFalse(VeilopolyMarkdownManual.filtered("股票").isEmpty)
  XCTAssertTrue(VeilopolyMarkdownManual.filtered("完全不存在的检索字符串9493921").isEmpty)
 }

 func testEveryBoardCellAndCardIndexHasAnEntry() {
  let text = VeilopolyMarkdownManual.markdown
  for index in 0..<40 {
   XCTAssertTrue(text.contains("| \(index) |"), "board slot \(index)")
  }
  for index in 0..<32 {
   let token = String(format: "| #%02d |", index)
   XCTAssertTrue(text.contains(token), "card \(index)")
  }
 }
 func testManualParsingDoesNotDependOnGameStateOrNetworking() {
  let first = VeilopolyMarkdownManual.sections
  let second = VeilopolyMarkdownManual.sections
  XCTAssertEqual(first, second)
  XCTAssertTrue(first.contains { $0.heading.contains("货币") })
  XCTAssertEqual(VeilopolyMarkdownManual.filtered("   ").count, first.count)
 }
}
