import XCTest
@testable import VeilopolyEngine

final class MalformedTurnReferenceTests: XCTestCase {
 private func rejected(_ game: GameState, _ move: Move,
                       file: StaticString = #filePath, line: UInt = #line) {
  let before = StateDigest.hash(game)
  guard case .failure(.invalidState) =
   VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move) else {
   return XCTFail("Corrupt reference must be rejected", file: file, line: line)
  }
  XCTAssertEqual(StateDigest.hash(game), before, file: file, line: line)
 }
 func testMalformedTradePartiesAndTiles() {
  for bad in [-1, 4, Int.max] {
   var g = GameFactory.make(seed: 9610, humanCount: 2)
   g.turn.phase = .trade
   g.trade = .init(from: bad, to: 1, offer: .init(), request: .init())
   rejected(g, Move(.acceptTrade, player: 1, seq: 0))
   g.trade = .init(from: 0, to: 1, offer: .init(tiles: [bad]), request: .init())
   rejected(g, Move(.acceptTrade, player: 1, seq: 0))
  }
 }
 func testMalformedAuctionParticipants() {
  var g = GameFactory.make(seed: 9611, humanCount: 2)
  g.turn.phase = .auction
  var a = AuctionState(tile: 1, active: [0,1])
  a.active = [0,Int.max]; a.turn = 0
  g.auction = a
  rejected(g, Move(.bid, player: 0, seq: 0, amount: 10))
  g.auction?.active = [0,0]
  rejected(g, Move(.bid, player: 0, seq: 0, amount: 10))
 }
 func testMalformedDebtAndNegativeDeckCursor() {
  var g = GameFactory.make(seed: 9612, humanCount: 2)
  g.turn.phase = .debt
  g.pendingDebt = .init(player: 0, amount: 100, creditor: Int.max)
  rejected(g, Move(.declareBankruptcy, player: 0, seq: 0))
  g = GameFactory.make(seed: 9613, humanCount: 2)
  g.turn.phase = .tileResolve
  g.players[0].position = 7
  g.chanceDeck.cursor = -1
  rejected(g, Move(.resolveTile, player: 0, seq: 0))
 }
 func testOverflowCountersAndHealthyReplay() throws {
  var bad = GameFactory.make(seed: 9614, humanCount: 2)
  bad.turn.rollCount = Int.max
  rejected(bad, Move(.rollDice, player: 0, seq: 0))
  bad = GameFactory.make(seed: 9615, humanCount: 2)
  bad.nextSeq = Int.max
  rejected(bad, Move(.rollDice, player: 0, seq: Int.max))
  let good = GameFactory.make(seed: 9616, humanCount: 2)
  let move = Move(.rollDice, player: 0, seq: 0)
  let a = try VeilopolyEngine.apply(good, VeilopolyEngine.context(good), move).get().0
  let b = try VeilopolyEngine.apply(good, VeilopolyEngine.context(good), move).get().0
  XCTAssertEqual(a, b)
 }
}
