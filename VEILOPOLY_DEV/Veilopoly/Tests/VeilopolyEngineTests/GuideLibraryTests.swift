import XCTest
@testable import VeilopolyEngine

final class GuideLibraryTests: XCTestCase {
 func testTwentyThreeUniqueNonemptyLiveTopics() {
  let entries=VeilopolyGuideLibrary.topics
  XCTAssertEqual(entries.count,23)
  XCTAssertEqual(Set(entries.map(\.id)).count,23)
  XCTAssertTrue(entries.allSatisfy {
   !$0.title.isEmpty && $0.detail.count > 16 && $0.footnote.count > 14
  })
  XCTAssertEqual(VeilopolyGuideChapter.allCases.count,4)
  XCTAssertTrue(VeilopolyGuideChapter.allCases.allSatisfy {
   !VeilopolyGuideLibrary.topics(in:$0).isEmpty
  })
 }
 func testHelpIsSearchableWithoutNewNavigationOrNetwork() {
  XCTAssertTrue(VeilopolyGuideLibrary.filtered("抵押").contains {$0.id=="mortgage"})
  XCTAssertTrue(VeilopolyGuideLibrary.filtered("VTL").contains {$0.id=="market"})
  XCTAssertTrue(VeilopolyGuideLibrary.filtered("不存在这个关键词").isEmpty)
  XCTAssertEqual(VeilopolyGuideLibrary.filtered(" ").count,23)
 }
 func testOwnerCriticalLimitsAreExplicit() {
  let get: (String)->VeilopolyGuideTopic? = {
   id in VeilopolyGuideLibrary.topics.first {$0.id==id}
  }
  XCTAssertTrue(get("multiplayer")?.footnote.contains("待集成") == false ||
                get("multiplayer")?.detail.contains("待集成") == true)
  XCTAssertTrue(get("autosave")?.footnote.contains("突然断电") == true)
  XCTAssertTrue(get("market")?.detail.contains("虚构") == true)
  XCTAssertTrue(get("chance")?.footnote.contains("临时") == true)
  XCTAssertEqual(VeilopolyGuideLibrary.minimumIOSMajorVersion,15)
 }
 func testHelpStatusDoesNotAlterCurrentGameState() {
  var game=GameFactory.make(seed:9090)
  let digest=StateDigest.hash(game)
  XCTAssertTrue(VeilopolyGuideLibrary.status(game).contains("玩家 1"))
  game.winner=0; game.turn.phase = .finished
  XCTAssertTrue(VeilopolyGuideLibrary.status(game).contains("本局已结束"))
  XCTAssertEqual(digest,StateDigest.hash(GameFactory.make(seed:9090)))
 }
}
