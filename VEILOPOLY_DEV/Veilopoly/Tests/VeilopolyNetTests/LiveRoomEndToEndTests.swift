import Foundation
import XCTest
import VeilopolyEngine
import VeilopolyAI
@testable import VeilopolyNet

final class LiveRoomEndToEndTests: XCTestCase {
 private func config() -> VeilopolyRoomConfiguration {
  .init(roomID: UUID().uuidString, seed: 9301, hostIdentityID: "host", guestIdentityID: "guest")
 }
 func testTwoPeerStateMachineRepairsDroppedCommitAndReorderedSnapshot() throws {
  let config = config()
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  var proposals = 0, repairs = 0
  for step in 0..<180 {
   let game = host.game
   if game.winner != nil { break }
   let actor = game.auction?.turn ?? game.trade?.to ?? game.pendingDebt?.player ?? game.turn.player
   let context = VeilopolyEngine.context(game)
   let move: Move
   if context.phase == .moveAnim { move = Move(.applyMovement, player: actor, seq: game.nextSeq) }
   else if context.phase == .tileResolve && game.turn.pendingPurchase == nil {
    move = Move(.resolveTile, player: actor, seq: game.nextSeq)
   } else {
    move = VeilopolyAI.decide(game, context, me: actor, level: .balanced)
   }
   if actor == 1 && ![MoveKind.applyMovement, .resolveTile, .stockTick].contains(move.type) {
    try host.validateProposal(move, from: "guest"); proposals += 1
   }
   let next = try host.commitOnHost(move).get().0
   XCTAssertTrue(VeilopolyLiveRoom.validSnapshotState(next, configuration: config), "Live snapshot admissibility at step \(step)")
   let committed = AuthoritativeMove(seq: move.seq, move: move, stateHash: StateDigest.hash(next))
   if step == 17 { continue } // Simulated packet loss, NOT a physical BLE test.
   do { _ = try guest.acceptCommit(committed, from: "host") }
   catch VeilopolyRoomError.sequenceGap {
    let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(host.game))
    var assembler = VeilopolyControlAssembler()
    var assembled: VeilopolyRoomPacket?
    for fragment in try VeilopolyControlCodec.fragments(packet).reversed() {
     if let result = try assembler.ingest(fragment, from: "host", now: 1) { assembled = result }
    }
    try guest.acceptSnapshot(XCTUnwrap(assembled?.snapshot), from: "host"); repairs += 1
   }
   XCTAssertEqual(StateDigest.hash(guest.game), StateDigest.hash(host.game))
   XCTAssertThrowsError(try guest.acceptCommit(committed, from: "host"))
  }
  XCTAssertGreaterThan(proposals, 0)
  XCTAssertEqual(repairs, 1)
 }
 func testFinancialOrdersCrossAuthorityWithoutDoubleCharging() throws {
  let config = config()
  var initial = GameFactory.make(seed: config.seed, humanCount: 2)
  initial.turn.player = 1; initial.turn.phase = .manage // Explicit scenario fixture, not a starting-game rule.
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host", restoredGame: initial)
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest", restoredGame: initial)
  let orders = [
   Move(.bankDeposit, player: 1, seq: 0, amount: 100, financeProduct: .demandDeposit),
   Move(.stockBuy, player: 1, seq: 1, stockSymbol: "VTL", stockShares: 5),
   Move(.stockSell, player: 1, seq: 2, stockSymbol: "VTL", stockShares: 2)
  ]
  for move in orders {
   try host.validateProposal(move, from: "guest")
   let next = try host.commitOnHost(move).get().0
   let committed = AuthoritativeMove(seq: move.seq, move: move, stateHash: StateDigest.hash(next))
   _ = try guest.acceptCommit(committed, from: "host")
   let cash = guest.game.players[1].cash
   XCTAssertThrowsError(try guest.acceptCommit(committed, from: "host"))
   XCTAssertEqual(guest.game.players[1].cash, cash)
   XCTAssertEqual(guest.game, host.game)
  }
 }
}
