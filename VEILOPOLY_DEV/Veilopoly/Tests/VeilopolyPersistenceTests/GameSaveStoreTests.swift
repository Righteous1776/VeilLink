import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyPersistence

final class VeilopolySaveStoreTests: XCTestCase {
 private func sandbox() throws -> (VeilopolySaveStore, URL) {
  let dir = FileManager.default.temporaryDirectory
   .appendingPathComponent("veilopoly-save-tests-\(UUID().uuidString)", isDirectory: true)
  return (try VeilopolySaveStore(directory: dir), dir)
 }
 func testInitialAndFullGameRoundTrip() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 991, humanCount: 1)
  XCTAssertNil(try store.load(gameID: "solo-1", mode: .solo))
  let checkpoint = try store.save(original, gameID: "solo-1", mode: .solo)
  XCTAssertEqual(checkpoint.revision, 1)
  XCTAssertEqual(checkpoint.stateHash, StateDigest.hash(original))
  let loaded = try XCTUnwrap(store.load(gameID: "solo-1", mode: .solo))
  XCTAssertEqual(loaded.game, original)
  XCTAssertEqual(loaded.game.seed, 991)
 }
 func testPreservesCommittedTurnAndRandomCounter() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let initial = GameFactory.make(seed: 641, humanCount: 1)
  _ = try store.save(initial, gameID: "solo", mode: .solo)
  let move = Move(.rollDice, player: 0, seq: initial.nextSeq)
  guard case .success((let after, _)) =
    VeilopolyEngine.apply(initial, VeilopolyEngine.context(initial), move)
  else { return XCTFail("expected deterministic roll") }
  let saved = try store.save(after, gameID: "solo", mode: .solo)
  XCTAssertEqual(saved.revision, 2)
  let restored = try XCTUnwrap(store.load(gameID: "solo", mode: .solo))
  XCTAssertEqual(restored.game, after)
  XCTAssertEqual(restored.game.nextSeq, 1)
  XCTAssertEqual(restored.game.rngCounter, after.rngCounter)
  XCTAssertEqual(restored.game.moveLog, after.moveLog)
 }
 func testCorruptedNewestSlotFallsBackToPrevious() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 42)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  var changed = original; changed.players[0].cash -= 12
  _ = try store.save(changed, gameID: "solo", mode: .solo)
  let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  let newest = try XCTUnwrap(files.first { $0.lastPathComponent.hasSuffix("-b.json") })
  try Data("broken-payload".utf8).write(to: newest, options: .atomic)
  let restored = try XCTUnwrap(store.load(gameID: "solo", mode: .solo))
  XCTAssertEqual(restored.revision, 1)
  XCTAssertEqual(restored.game, original)
 }
 func testBothCorruptSlotsFailRatherThanSilentlyStartingOver() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 11)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  for url in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
   try Data("corrupt".utf8).write(to: url, options: .atomic)
  }
  XCTAssertThrowsError(try store.load(gameID: "solo", mode: .solo)) { err in
   XCTAssertEqual(err as? VeilopolySaveError, .corruptCheckpoint)
  }
 }
 func testModeAndSessionIDsNeverShareSlots() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let game = GameFactory.make(seed: 17)
  _ = try store.save(game, gameID: "room-abc", mode: .multiplayerHost)
  XCTAssertNil(try store.load(gameID: "room-abc", mode: .multiplayerGuest))
  XCTAssertNil(try store.load(gameID: "room-other", mode: .multiplayerHost))
  XCTAssertNil(try store.load(gameID: "room-abc", mode: .solo))
  XCTAssertNotNil(try store.load(gameID: "room-abc", mode: .multiplayerHost))
 }
 func testRejectsMalformedGameAndPathTraversalIdentity() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 18)
  var invalid = original; invalid.players[0].position = 90
  XCTAssertThrowsError(try store.save(invalid, gameID: "solo", mode: .solo))
  XCTAssertThrowsError(try store.save(original, gameID: "", mode: .solo))
  _ = try store.save(original, gameID: "../../safe", mode: .solo)
  let names = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  XCTAssertTrue(names.allSatisfy { $0.deletingLastPathComponent() == dir })
 }
 func testResetCreatesNewerRevisionWithoutResurrectingOldRun() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let first = GameFactory.make(seed: 7, humanCount: 1)
  let second = GameFactory.make(seed: 8, humanCount: 1)
  _ = try store.save(first, gameID: "solo-1", mode: .solo)
  _ = try store.save(second, gameID: "solo-1", mode: .solo)
  XCTAssertEqual(try store.load(gameID: "solo-1", mode: .solo)?.game.seed, 8)
 }
 func testCorruptSlotQuarantineRequiresExplicitCall() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 515)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  for path in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
   try Data("unreadable".utf8).write(to: path, options: .atomic)
  }
  XCTAssertThrowsError(try store.load(gameID: "solo", mode: .solo))
  XCTAssertTrue(try store.quarantineUnreadable(gameID: "solo", mode: .solo))
  XCTAssertNil(try store.load(gameID: "solo", mode: .solo))
  let dirOfCorrupt = dir.appendingPathComponent("Quarantine")
  XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dirOfCorrupt.path).count, 2)
  _ = try store.save(GameFactory.make(seed: 516), gameID: "solo", mode: .solo)
  XCTAssertEqual(try store.load(gameID: "solo", mode: .solo)?.game.seed, 516)
 }

}
