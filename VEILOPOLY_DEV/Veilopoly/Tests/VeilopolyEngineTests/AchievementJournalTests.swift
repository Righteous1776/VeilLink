import XCTest
@testable import VeilopolyEngine

final class AchievementJournalTests: XCTestCase {
 private func find(_ id: String, in state: GameState, seat: Int = 0) -> VeilopolyAchievement? {
  VeilopolyAchievements.entries(in: state, player: seat).first { $0.id == id }
 }

 func testNewMatchShowsSixteenLockedEntriesWithoutMutatingState() {
  let game = GameFactory.make(seed: 9411, humanCount: 2)
  let old = StateDigest.hash(game)
  let entries = VeilopolyAchievements.entries(in: game, player: 0)
  XCTAssertEqual(entries.count, 16)
  XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
  XCTAssertTrue(entries.allSatisfy { !$0.unlocked })
  XCTAssertEqual(StateDigest.hash(game), old)
 }

 func testCommittedMoveLogIsSeatIsolatedAndOnlyPositiveBidsCount() {
  var game = GameFactory.make(seed: 9412, humanCount: 2)
  game.moveLog = [
   Move(.rollDice, player: 0, seq: 0),
   Move(.bid, player: 0, seq: 1, amount: 0),
   Move(.bid, player: 0, seq: 2, amount: 42),
   Move(.bankDeposit, player: 1, seq: 3, amount: 100),
   Move(.stockBuy, player: 1, seq: 4, stockSymbol: "VTL", stockShares: 1),
   Move(.buyProperty, player: 0, seq: 5, tile: 1)
  ]
  let old = StateDigest.hash(game)
  XCTAssertEqual(find("auction", in: game)?.progress, 1)
  XCTAssertTrue(find("first-roll", in: game)?.unlocked == true)
  XCTAssertTrue(find("first-deed", in: game)?.unlocked == true)
  XCTAssertFalse(find("deposit", in: game)?.unlocked ?? true)
  XCTAssertTrue(find("deposit", in: game, seat: 1)?.unlocked == true)
  XCTAssertTrue(find("market-entry", in: game, seat: 1)?.unlocked == true)
  XCTAssertEqual(StateDigest.hash(game), old)
 }

 func testCurrentAssetGoalsRecalculateAfterTradeAndHotelLoss() {
  var game = GameFactory.make(seed: 9413)
  game.board[1].owner = 0
  game.board[3].owner = 0
  game.board[6].owner = 0
  game.board[1].hotel = true
  XCTAssertTrue(find("three-assets", in: game)?.unlocked == true)
  XCTAssertTrue(find("color-set", in: game)?.unlocked == true)
  XCTAssertTrue(find("hotel", in: game)?.unlocked == true)
  game.board[3].owner = 1
  game.board[1].hotel = false
  XCTAssertFalse(find("color-set", in: game)?.unlocked ?? true)
  XCTAssertFalse(find("hotel", in: game)?.unlocked ?? true)
  XCTAssertFalse(find("three-assets", in: game)?.unlocked ?? true)
 }

 func testInvalidSeatsAndWinnerUseCanonicalStateOnly() {
  var game = GameFactory.make(seed: 9414)
  XCTAssertTrue(VeilopolyAchievements.entries(in: game, player: -1).isEmpty)
  XCTAssertTrue(VeilopolyAchievements.entries(in: game, player: Int.max).isEmpty)
  game.winner = 2
  XCTAssertFalse(find("victory", in: game, seat: 0)?.unlocked ?? true)
  XCTAssertTrue(find("victory", in: game, seat: 2)?.unlocked == true)
 }
}
