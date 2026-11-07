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
 func testOutOfRangeDeedReferencesCannotReplaceCheckpoint() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 8203, humanCount: 1)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  for index in [-1, 40, Int.min, Int.max] {
   for phase in [Phase.tileResolve, .auction] {
    var invalid = original
    invalid.turn.phase = phase
    if phase == .tileResolve { invalid.turn.pendingPurchase = index }
    else { invalid.auction = AuctionState(tile: index, active: [0, 1]) }
    XCTAssertThrowsError(try store.save(invalid, gameID: "solo", mode: .solo)) { error in
     XCTAssertEqual(error as? VeilopolySaveError, .invalidGameState)
    }
    let restored = try XCTUnwrap(store.load(gameID: "solo", mode: .solo))
    XCTAssertEqual(restored.revision, 1)
    XCTAssertTrue(restored.game == original)
   }
  }
 }

 func testLoadSkipsCorrectlyChecksummedInvalidDeedReferences() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 8204, humanCount: 1)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  _ = try store.save(original, gameID: "solo", mode: .solo)
  let paths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  let olderSlot = try XCTUnwrap(paths.first { $0.lastPathComponent.hasSuffix("-a.json") })
  for phase in [Phase.tileResolve, .auction] {
   var invalid = original
   invalid.turn.phase = phase
   if phase == .tileResolve { invalid.turn.pendingPurchase = 40 }
   else { invalid.auction = AuctionState(tile: 40, active: [0, 1]) }
   let record = VeilopolySavedGame(schema: 1, gameID: "solo", mode: .solo,
    revision: 3, savedAt: 1, stateHash: StateDigest.hash(invalid), game: invalid)
   let encoder = JSONEncoder()
   encoder.outputFormatting = [.sortedKeys]
   let plain = try encoder.encode(record)
   var hash: UInt64 = 14_695_981_039_346_656_037
   for byte in plain { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
   let hex = String(hash, radix: 16)
   struct SealedFixture: Encodable { let record: VeilopolySavedGame; let checksum: String }
   let envelope = SealedFixture(record: record,
    checksum: String(repeating: "0", count: max(0, 16 - hex.count)) + hex)
   try encoder.encode(envelope).write(to: olderSlot, options: .atomic)
   let restored = try XCTUnwrap(store.load(gameID: "solo", mode: .solo))
   XCTAssertEqual(restored.revision, 2, "Semantic validation must reject even a checksum-valid malformed slot")
   XCTAssertTrue(restored.game == original)
  }
 }

 func testRejectsMalformedGameAndPathTraversalIdentity() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let original = GameFactory.make(seed: 18)
  var invalid = original; invalid.players[0].position = 90
  XCTAssertThrowsError(try store.save(invalid, gameID: "solo", mode: .solo))
  XCTAssertThrowsError(try store.save(original, gameID: "", mode: .solo))
  _ = try store.save(original, gameID: "../../safe", mode: .solo)
  let names = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  XCTAssertFalse(names.isEmpty)
  // Darwin may return a /private/var URL for the same temporary directory,
  // and URL equality also includes directory metadata. Compare canonical paths
  // while retaining the assertion that every actual file is directly inside it.
  let root = dir.resolvingSymlinksInPath().standardizedFileURL.path
  XCTAssertTrue(names.allSatisfy {
   $0.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == root
  })
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

 func testReceiptsRoundTripInSameAtomicCheckpoint() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  var initial = GameFactory.make(seed: 20261107, humanCount: 1)
  initial.turn.phase = .manage
  let order = Move(.stockBuy, player: 0, seq: initial.nextSeq,
                   stockSymbol: "VTL", stockShares: 3)
  guard case .success((let traded, let effects)) =
   VeilopolyEngine.apply(initial, VeilopolyEngine.context(initial), order),
   let fill = effects.first(where: { $0.kind == .stockBought }),
   let price = fill.stockPriceCents, let delta = fill.amount else {
    return XCTFail("Expected a canonical stock buy")
  }
  let receipt = VeilopolyStockExecutionRecord(id: 0, symbol: "VTL", shares: 3,
                    priceCents: price, cashDelta: delta, bought: true, player: 0)
  _ = try store.save(traded, gameID: "solo-1", mode: .solo,
                     stockReceipts: [receipt])
  let restored = try XCTUnwrap(store.load(gameID: "solo-1", mode: .solo))
  XCTAssertEqual(restored.game, traded)
  XCTAssertEqual(restored.stockReceipts, [receipt])
  XCTAssertEqual(restored.stateHash, StateDigest.hash(traded))
  // All receipt metadata is outside GameState and doesn't affect net replay.
  XCTAssertEqual(restored.game.nextSeq, traded.nextSeq)
 }
 func testOldSealedSavesStayByteCompatibleWithoutExtraKey() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let game = GameFactory.make(seed: 551)
  _ = try store.save(game, gameID: "legacy", mode: .solo)
  let slot = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys:nil)
    .first { $0.lastPathComponent.hasSuffix("-a.json") })
  let json = try String(contentsOf: slot, encoding: .utf8)
  XCTAssertFalse(json.contains("stockReceipts"))
  XCTAssertNil(try store.load(gameID: "legacy", mode: .solo)?.stockReceipts)
 }
 func testRejectsForgedOrOtherSessionReceipts() throws {
  let (store, dir) = try sandbox(); defer { try? FileManager.default.removeItem(at: dir) }
  let game = GameFactory.make(seed: 773)
  let forged = VeilopolyStockExecutionRecord(id: 0, symbol: "VTL", shares: 2,
               priceCents: 1_850, cashDelta: -38, bought: true, player: 0)
  XCTAssertThrowsError(try store.save(game, gameID: "solo", mode: .solo,
                         stockReceipts: [forged]))
  _ = try store.save(game, gameID: "solo", mode: .solo, stockReceipts: [])
  XCTAssertEqual(try store.load(gameID: "solo", mode: .solo)?.stockReceipts, [])
 }

}
