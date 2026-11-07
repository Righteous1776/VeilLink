import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyPersistence

final class CityTreasuryPersistenceTests: XCTestCase {
 func testCorruptMoneySupplyIsRejectedBeforeReplacingLastGoodSlot() throws {
  let dir = FileManager.default.temporaryDirectory
   .appendingPathComponent("veilopoly-city-bank-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: dir) }
  let store = try VeilopolySaveStore(directory: dir)
  let good = VeilopolyCityLongEconomy.make(seed: 98111)
  _ = try store.save(good, gameID: "treasury", mode: .solo)
  var bad = good
  bad.players[0].cash += 200
  XCTAssertThrowsError(try store.save(bad, gameID: "treasury", mode: .solo)) { err in
   XCTAssertEqual(err as? VeilopolySaveError, .invalidGameState)
  }
  bad = good; bad.banking?.reserveCash = -1
  XCTAssertThrowsError(try store.save(bad, gameID: "treasury", mode: .solo))
  bad = good; bad.banking?.reserveCash = nil
  XCTAssertThrowsError(try store.save(bad, gameID: "treasury", mode: .solo))
  let restored = try XCTUnwrap(store.load(gameID: "treasury", mode: .solo))
  XCTAssertEqual(restored.game, good)
  XCTAssertEqual(restored.game.banking?.reserveCash, 160000)
  XCTAssertEqual(StateDigest.hash(restored.game), StateDigest.hash(good))
 }
}
