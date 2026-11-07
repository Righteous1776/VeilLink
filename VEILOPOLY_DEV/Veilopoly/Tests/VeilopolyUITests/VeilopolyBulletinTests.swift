import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class VeilopolyBulletinTests: XCTestCase {
 private func note(_ id: Int, priority: Int = 40) -> VeilopolyBulletin {
  .init(id: "n\(id)", topic: "t\(id)", text: "玩家完成一笔真实成交。", category: .event, priority: priority)
 }
 func testCommittedRentContainsActualPayerRecipientAndAmount() throws {
  var game = GameFactory.make(seed: 512)
  game.turn.phase = .tileResolve; game.players[0].position = 1; game.board[1].owner = 1
  let (next, effects) = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game),
    Move(.resolveTile, player: 0, seq: 0)).get()
  let notice = try XCTUnwrap(VeilopolyBulletinCopy.event(effects, state: next, sequence: 0))
  XCTAssertTrue(notice.text.contains(next.players[1].name))
  XCTAssertTrue(notice.text.contains("¥2"))
  XCTAssertEqual(notice.priority, 70)
  game.pendingDebt = PendingDebt(player: 0, amount: 2, creditor: 1)
  XCTAssertNil(VeilopolyBulletinCopy.event([Effect(.rentPaid, player: 0, tile: 1, to: 1, amount: 2)], state: game, sequence: 0))
 }
 func testRoutineEventsDoNotFloodNewsAndCopyDoesNotMutateGameRNG() {
  let game = GameFactory.make(seed: 513)
  let hash = StateDigest.hash(game)
  XCTAssertNil(VeilopolyBulletinCopy.event([Effect(.diceRolled), Effect(.turnEnded), Effect(.stockTicked)], state: game, sequence: 1))
  let effects = [Effect(.cashChanged, player: 2, amount: 100)]
  let first = VeilopolyBulletinCopy.event(effects, state: game, sequence: 4)
  XCTAssertEqual(first, VeilopolyBulletinCopy.event(effects, state: game, sequence: 4))
  XCTAssertTrue(first?.text.contains("100") == true)
  XCTAssertEqual(StateDigest.hash(game), hash)
 }
 func testQueueIsBoundedDeduplicatedAndKeepsPriority() {
  var feed = VeilopolyBulletinFeed()
  feed.enqueue(note(0)); feed.enqueue(note(0))
  XCTAssertEqual(feed.current?.id, "n0"); XCTAssertEqual(feed.queued.count, 0)
  for i in 1...20 { feed.enqueue(note(i)) }
  XCTAssertEqual(feed.queued.count, VeilopolyBulletinFeed.capacity)
  feed.enqueue(note(99, priority: 100))
  XCTAssertEqual(feed.queued.first?.id, "n99")
  feed.advance(by: 14, seed: 0)
  XCTAssertNil(feed.current)
  feed.advance(by: 6, seed: 0); XCTAssertNil(feed.current)
  feed.advance(by: 2, seed: 0); XCTAssertEqual(feed.current?.id, "n99")
 }
 func testCityNewsIsLowFrequencyAndUrgentEventsCanReplaceIt() {
  var feed = VeilopolyBulletinFeed()
  feed.advance(by: 2, seed: 7)
  XCTAssertEqual(feed.current?.category, .city)
  feed.enqueue(note(100, priority: 100))
  XCTAssertEqual(feed.current?.category, .event)
  var quiet = VeilopolyBulletinFeed()
  quiet.advance(by: 2, seed: 7); quiet.advance(by: 14, seed: 7)
  XCTAssertNil(quiet.current)
  quiet.advance(by: 30, seed: 7); XCTAssertNil(quiet.current)
  quiet.advance(by: 2, seed: 7); XCTAssertEqual(quiet.current?.id, "city-1")
 }
 func testMarketNewsRequiresActualChangeOrNewHalt() {
  let old = StockMarketEngine.initial(seed: 8)
  XCTAssertNil(VeilopolyBulletinCopy.market(before: old, after: old, sequence: 0))
  var market = old; market.regime = -1
  XCTAssertTrue(VeilopolyBulletinCopy.market(before: old, after: market, sequence: 1)?.text.contains("偏弱") == true)
  market.quotes[0].haltedTicks = 2
  XCTAssertTrue(VeilopolyBulletinCopy.market(before: old, after: market, sequence: 2)?.text.contains("VTL") == true)
 }
 func testLocalCopyLibraryIsVariedAndShort() {
  let lines = VeilopolyBulletinCopy.cityLines + VeilopolyBulletinCopy.eventTemplates.values.flatMap { $0 }
  XCTAssertGreaterThanOrEqual(lines.count, 80)
  XCTAssertEqual(Set(lines).count, lines.count)
  XCTAssertTrue(lines.allSatisfy { !$0.isEmpty && $0.count <= 80 && !$0.contains("http") })
 }
 func testFinancialCopyHandlesExtremeSignedValuesWithoutOverflow() {
  let game = GameFactory.make(seed: 10)
  let notice = VeilopolyBulletinCopy.event([Effect(.cashChanged, player: 0, amount: Int.min)],
                                          state: game, sequence: 10)
  XCTAssertTrue(notice?.text.contains(String(Int.min.magnitude)) == true)
 }
 func testNewsFitsBesideBoardAndAwayFromExitOnPhoneAndTablet() {
  for (width, height) in [(844.0,390.0),(852.0,393.0),(1180.0,820.0)] {
   let board = VeilopolyLandscapeLayout.maximizedBoardSize(availableWidth: width, availableHeight: height)
   let ticker = VeilopolyLandscapeLayout.bulletinWidth(availableWidth: width, boardWidth: board.width)
   XCTAssertGreaterThanOrEqual(ticker, 90)
   XCTAssertLessThanOrEqual(board.width + 16 + ticker, width - 112)
  }
 }
}
