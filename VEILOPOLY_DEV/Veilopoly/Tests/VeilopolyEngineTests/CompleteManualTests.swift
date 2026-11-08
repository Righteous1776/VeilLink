import XCTest
@testable import VeilopolyEngine

final class CompleteManualTests: XCTestCase {
 func testOneCanonicalBookContains13ChaptersAnd162UniqueEntries() {
  let all = VeilopolyCompleteManual.entries
  XCTAssertEqual(VeilopolyCompleteManual.chapters.count, 13)
  XCTAssertEqual(all.count, 162)
  XCTAssertEqual(Set(all.map(\.id)).count, 162)
  XCTAssertTrue(all.allSatisfy {
   !$0.title.isEmpty && !$0.subtitle.isEmpty &&
   $0.paragraphs.count >= 2 && !$0.evidence.isEmpty
  })
  let boardEntries = all.filter { $0.chapter == "appendix" && $0.id.hasPrefix("board-") }
  XCTAssertEqual(boardEntries.count, 40)
  XCTAssertEqual(Set(boardEntries.map(\.id)), Set((0..<40).map { "board-" + ($0 < 10 ? "0" : "") + String($0) }))
  XCTAssertEqual(all.filter { $0.id.hasPrefix("card-") }.count, 32)
  XCTAssertEqual(Set(all.map(\.chapter)).count, 13)
 }
 func testChapterAndFullTextSearchBehavePredictably() {
  XCTAssertTrue(VeilopolyCompleteManual.search("免费建房").count > 0)
  XCTAssertTrue(VeilopolyCompleteManual.search("VTL").count > 0)
  XCTAssertTrue(VeilopolyCompleteManual.search("债权").count > 0)
  XCTAssertTrue(VeilopolyCompleteManual.search("不存在的关键词xxxx").isEmpty)
  XCTAssertEqual(VeilopolyCompleteManual.search(" ").count, 162)
  XCTAssertTrue(VeilopolyCompleteManual.search("", in: "appendix").count >= 72)
  XCTAssertTrue(VeilopolyCompleteManual.search("银行", in: "board").isEmpty ||
                VeilopolyCompleteManual.search("银行", in: "board").allSatisfy { $0.chapter == "board" })
 }
 func testExplicitVersionBoundariesAreVisibleToReader() {
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(5).contains("V5"))
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(4).contains("V4"))
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(3).contains("V3"))
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(nil).contains("经典"))
  XCTAssertTrue(VeilopolyCompleteManual.deploymentStatus.contains("待"))
  XCTAssertTrue(VeilopolyCompleteManual.entries.contains {
   $0.id == "intro-version" && $0.paragraphs.joined().contains("2,100,000")
  })
 }
}
