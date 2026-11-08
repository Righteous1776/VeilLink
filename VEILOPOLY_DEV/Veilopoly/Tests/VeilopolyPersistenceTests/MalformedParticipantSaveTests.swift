import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyPersistence

final class MalformedParticipantSaveTests: XCTestCase {
 func testRejectMalformedReferencesAndPreserveLastGoodSlot() throws {
  let directory = FileManager.default.temporaryDirectory
   .appendingPathComponent("veilopoly-ref-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = try VeilopolySaveStore(directory: directory)
  let good = GameFactory.make(seed: 9761, humanCount: 2)
  _ = try store.save(good, gameID: "ref-gates", mode: .solo)
  var states: [GameState] = []
  var g = good
  g.trade = TradeState(from: Int.max, to: 1, offer: .init(), request: .init())
  states.append(g)
  g = good
  g.trade = TradeState(from: 0, to: 1, offer: .init(tiles: [Int.max]), request: .init())
  states.append(g)
  g = good
  g.turn.phase = .auction; g.auction = AuctionState(tile: 1, active: [0, 1])
  g.auction?.bidder = -1; states.append(g)
  g = good
  g.pendingDebt = PendingDebt(player: 0, amount: 100, creditor: Int.max)
  states.append(g)
  g = good; g.turn.player = Int.max; states.append(g)
  g = good; g.chanceDeck.cursor = -1; states.append(g)
  g = good; g.turn.rollCount = Int.max; states.append(g)
  for broken in states {
   XCTAssertThrowsError(try store.save(broken, gameID: "ref-gates", mode: .solo)) { error in
    XCTAssertEqual(error as? VeilopolySaveError, .invalidGameState)
   }
  }
  XCTAssertEqual(try store.load(gameID: "ref-gates", mode: .solo)?.game, good)
 }
}
