import XCTest
import VeilopolyNet
import VeilopolyEngine

final class ReplicationTests: XCTestCase {
 func testHostReplayGapSnapshotAndResync() throws {
  let initial = GameFactory.make(seed: 5151)
  var host = AuthoritativeHost(game: initial)
  var client = ReplicaClient(game: initial)
  var packets: [AuthoritativeMove] = []
  for i in 0..<12 {
   let g = host.game; let p = g.turn.player
   let kind: MoveKind = g.turn.phase == .roll ? .rollDice :
     g.turn.phase == .moveAnim ? .applyMovement :
     g.turn.phase == .tileResolve ? (g.turn.pendingPurchase == nil ? .resolveTile : .startAuction) :
     g.turn.phase == .manage ? .endTurn : .bid
   let move = Move(kind, player: g.auction?.turn ?? p, seq: g.nextSeq,
                   tile: g.turn.pendingPurchase, amount: kind == .bid ? 0 : nil)
   switch host.accept(move) {
   case .success(let packet): packets.append(packet)
   case .failure(let err): XCTFail("host step \(i): \(err)"); return
   }
  }
  // One dropped packet must be detected as a gap.
  _ = client.replay(packets[0]); _ = client.replay(packets[1])
  switch client.replay(packets[3]) {
  case .failure(let e): XCTAssertEqual(e, .seqGap)
  case .success: XCTFail("gap went undetected")
  }
  for packet in host.missing(afterSeq: 1) {
   switch client.replay(packet) {
   case .success: break
   case .failure(let e): XCTFail("replay \(e)")
   }
  }
  XCTAssertEqual(StateDigest.hash(client.game), StateDigest.hash(host.game))
  var other = ReplicaClient(game: initial)
  let snapshot = host.snapshot()
  switch other.resync(snapshot) {
  case .success(let hash): XCTAssertEqual(hash, StateDigest.hash(host.game))
  case .failure: XCTFail("resync failed")
  }
 }
}
