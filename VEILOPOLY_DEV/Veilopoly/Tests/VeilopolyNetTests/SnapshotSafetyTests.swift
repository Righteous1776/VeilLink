import XCTest
import VeilopolyNet
import VeilopolyEngine

final class SnapshotSafetyTests: XCTestCase {
 func testOldSnapshotCannotRollbackAcceptedMoves() {
  let initial = GameFactory.make(seed: 701)
  let old = GameSnapshot(initial)
  var host = AuthoritativeHost(game: initial)
  var replica = ReplicaClient(game: initial)
  let move = Move(.rollDice, player: 0, seq: 0)
  guard case .success(let packet) = host.accept(move) else { return XCTFail("host move") }
  guard case .success = replica.replay(packet) else { return XCTFail("replica move") }
  let before = replica.game
  guard case .failure(.staleSnapshot) = replica.resync(old) else { return XCTFail("rollback accepted") }
  XCTAssertEqual(replica.game, before)
 }

 func testDifferentSeedCannotOverwriteSession() {
  let initial = GameFactory.make(seed: 701)
  var replica = ReplicaClient(game: initial)
  guard case .failure(.sessionMismatch) = replica.resync(GameSnapshot(GameFactory.make(seed: 702)))
  else { return XCTFail("different session accepted") }
  XCTAssertEqual(replica.game, initial)
 }

 func testMoveLogSeqMismatchDoesNotCorruptReplica() {
  let initial = GameFactory.make(seed: 701)
  var tampered = initial
  tampered.nextSeq = 1 // an apparently newer snapshot with no logged move
  var replica = ReplicaClient(game: initial)
  guard case .failure(.corruptSnapshot) = replica.resync(GameSnapshot(tampered))
  else { return XCTFail("inconsistent log accepted") }
  XCTAssertEqual(replica.game, initial)
 }

 func testSameSequenceTrustedSnapshotCanStillRepairDivergence() {
  let initial = GameFactory.make(seed: 701)
  var replica = ReplicaClient(game: initial)
  var corrected = initial
  corrected.players[0].cash += 20
  let hash = StateDigest.hash(corrected)
  guard case .success(hash) = replica.resync(GameSnapshot(corrected))
  else { return XCTFail("valid same-sequence recovery unexpectedly refused") }
  XCTAssertEqual(replica.game, corrected)
 }

 func testHostReplayAndSnapshotRemainConsistent() {
  let initial = GameFactory.make(seed: 701)
  var host = AuthoritativeHost(game: initial)
  var replica = ReplicaClient(game: initial)
  let move = Move(.rollDice, player: 0, seq: 0)
  guard case .success(let packet) = host.accept(move) else { return XCTFail("host") }
  XCTAssertEqual(replica.replay(packet).successValue, packet.stateHash)
  XCTAssertEqual(replica.resync(host.snapshot()).successValue, packet.stateHash)
 }
}
private extension Result {
 var successValue: Success? { if case .success(let result) = self { return result }; return nil }
}
