import XCTest
import VeilopolyNet
import VeilopolyEngine

final class CorruptionTests: XCTestCase {
 func testFakeHashRequiresResyncAndNeverMutatesReplica() {
  let initial = GameFactory.make(seed: 99)
  var host = AuthoritativeHost(game: initial)
  var replica = ReplicaClient(game: initial)
  let move = Move(.rollDice, player: 0, seq: 0)
  guard case .success(let authoritative) = host.accept(move) else { return XCTFail("host") }
  let tampered = AuthoritativeMove(seq: 0,move: move,stateHash:"bad")
  XCTAssertEqual(replica.replay(tampered).failureValue, .hashMismatch)
  XCTAssertEqual(replica.game,initial)
  XCTAssertEqual(replica.replay(authoritative).successValue,authoritative.stateHash)
 }
 func testSnapshotMustBeAuthenticatedOutsideTransportBoundary() {
  let initial = GameFactory.make(seed: 99)
  var replica = ReplicaClient(game: initial)
  var altered = initial; altered.players[0].cash = 10
  let fake = GameSnapshot(altered)
  XCTAssertEqual(replica.resync(fake).successValue,StateDigest.hash(altered))
  XCTAssertEqual(replica.game.players[0].cash,10)
 }
}
private extension Result {
 var failureValue: Failure? { if case .failure(let error) = self { return error }; return nil }
 var successValue: Success? { if case .success(let result) = self { return result }; return nil }
}
