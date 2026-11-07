import XCTest
@testable import VeilopolyEngine

final class CompleteManualTests: XCTestCase {
 func testHandbookCoverageUniqueIdsAndAllChapters() {
  let entries = VeilopolyCompleteManual.entries
  XCTAssertEqual(VeilopolyCompleteManual.chapters.count, 13)
  XCTAssertEqual(entries.count, 162)
  XCTAssertEqual(Set(entries.map(\.id)).count, 162)
  XCTAssertEqual(entries.filter { $0.id.hasPrefix("board-") && $0.id.count == 8 }.count, 40)
  XCTAssertEqual(entries.filter { $0.id.hasPrefix("card-") }.count, 32)
  XCTAssertTrue(entries.allSatisfy {
   !$0.title.isEmpty && !$0.subtitle.isEmpty && !$0.evidence.isEmpty &&
   !$0.paragraphs.isEmpty && $0.paragraphs.allSatisfy { !$0.isEmpty }
  })
  for chapter in VeilopolyCompleteManual.chapters {
   XCTAssertTrue(entries.contains { $0.chapter == chapter.id })
  }
 }
 func testVersionAwareTextDoesNotRewriteGameState() {
  let g = VeilopolyCityLongEconomy.make(seed: 26018)
  let digest = StateDigest.hash(g)
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(5).contains("V5"))
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(4).contains("V4"))
  XCTAssertTrue(VeilopolyCompleteManual.currentProfile(nil).contains("经典"))
  XCTAssertFalse(VeilopolyCompleteManual.search("VTL").isEmpty)
  XCTAssertFalse(VeilopolyCompleteManual.search("免费建房").isEmpty)
  XCTAssertEqual(VeilopolyCompleteManual.search("").count, 162)
  XCTAssertEqual(VeilopolyCompleteManual.search("", in: "bank").count, 12)
  XCTAssertEqual(VeilopolyCompleteManual.search("不存在此术语").count, 0)
  XCTAssertEqual(StateDigest.hash(g), digest)
 }
 func testLegacyShortGuideRemainsUnmodified() {
  XCTAssertEqual(VeilopolyGuideLibrary.topics.count, 23)
 }
}
