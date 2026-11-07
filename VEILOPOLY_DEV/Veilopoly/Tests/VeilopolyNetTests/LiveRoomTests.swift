import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyNet

final class LiveRoomTests: XCTestCase {
 private var config: VeilopolyRoomConfiguration {
  .init(roomID: "831BA512-EE4D-44AE-ABF7-005769FD2648", seed: 9101,
        hostIdentityID: "host", guestIdentityID: "guest")
 }
 func testHostCommitGuestReplayDuplicateAndSpoofedSender() throws {
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let move = Move(.rollDice, player: 0, seq: 0)
  let next = try host.commitOnHost(move).get().0
  let packet = AuthoritativeMove(seq: 0, move: move, stateHash: StateDigest.hash(next))
  XCTAssertThrowsError(try guest.acceptCommit(packet, from: "stranger"))
  _ = try guest.acceptCommit(packet, from: "host")
  XCTAssertEqual(guest.game, host.game)
  XCTAssertThrowsError(try guest.acceptCommit(packet, from: "host"))
  XCTAssertEqual(guest.game.nextSeq, 1)
 }
 func testGuestCannotDriveAutomaticMovesOrOtherSeats() throws {
  let host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  XCTAssertThrowsError(try host.validateProposal(Move(.rollDice, player: 0, seq: 0), from: "guest"))
  for kind in [MoveKind.stockTick, .resolveTile, .applyMovement] {
   XCTAssertThrowsError(try host.validateProposal(Move(kind, player: 1, seq: 0), from: "guest"))
  }
  XCTAssertThrowsError(try host.validateProposal(Move(.rollDice, player: 1, seq: 0), from: "stranger"))
  XCTAssertNoThrow(try host.validateProposal(Move(.rollDice, player: 1, seq: 0), from: "guest"))
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  guard case .failure(.notYourTurn) = guest.commitOnHost(Move(.rollDice, player: 0, seq: 0)) else {
   return XCTFail("A guest cannot become authoritative")
  }
 }
 func testWrongHashGapAndSnapshotRollbackAreAtomic() throws {
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let old = GameSnapshot(guest.game)
  let move = Move(.rollDice, player: 0, seq: 0)
  let next = try host.commitOnHost(move).get().0
  XCTAssertThrowsError(try guest.acceptCommit(.init(seq: 1, move: move, stateHash: "bad"), from: "host"))
  XCTAssertThrowsError(try guest.acceptCommit(.init(seq: 0, move: move, stateHash: "bad"), from: "host"))
  XCTAssertEqual(guest.game.nextSeq, 0)
  try guest.acceptSnapshot(GameSnapshot(next), from: "host")
  XCTAssertThrowsError(try guest.acceptSnapshot(old, from: "host"))
  XCTAssertEqual(guest.game, next)
 }
 func testMalformedSnapshotCannotReachActorOrBoardSubscripts() throws {
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let original = guest.game
  for index in [-1, 4, Int.max] {
   var invalid = original
   invalid.trade = TradeState(from: 0, to: index, offer: .init(), request: .init())
   invalid.turn.phase = .trade
   XCTAssertThrowsError(try guest.acceptSnapshot(GameSnapshot(invalid), from: "host"))
   XCTAssertTrue(guest.game == original)
  }
 }
 func testPacketShapeRoomAndPeerAreBoundToAuthenticatedSession() throws {
  let room = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .accept)
  XCTAssertNoThrow(try room.validate(packet, from: "host"))
  XCTAssertThrowsError(try room.validate(packet, from: "stranger"))
  XCTAssertFalse(VeilopolyRoomPacket(roomID: config.roomID, kind: .commit).isValid)
  XCTAssertFalse(VeilopolyRoomPacket(roomID: config.roomID, kind: .accept, nextSeq: 1).isValid)
  XCTAssertThrowsError(try room.validate(.init(roomID: UUID().uuidString, kind: .leave), from: "host"))
 }
 func testFragmentedSnapshotReordersDeduplicatesAndKeepsPeerIsolation() throws {
  let room = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(room.game))
  let fragments = try VeilopolyControlCodec.fragments(packet)
  XCTAssertGreaterThan(fragments.count, 1)
  var assembler = VeilopolyControlAssembler()
  XCTAssertNil(try assembler.ingest(fragments[0], from: "wrong-peer", now: 1))
  var received: VeilopolyRoomPacket?
  for fragment in fragments.reversed() {
   let value = try assembler.ingest(fragment, from: "host", now: 1)
   if let value { received = value }
  }
  XCTAssertEqual(received?.snapshot?.game, room.game)
  for fragment in fragments { XCTAssertNil(try assembler.ingest(fragment, from: "host", now: 2)) }
 }
 func testFragmentsInterleaveAndTimeoutWithoutUnboundedGrowth() throws {
  let room = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(room.game))
  let first = try VeilopolyControlCodec.fragments(packet)
  let second = try VeilopolyControlCodec.fragments(packet)
  var assembler = VeilopolyControlAssembler()
  var completed = 0
  for index in first.indices {
   for slice in [first[index], second[index]] {
    if try assembler.ingest(slice, from: "host", now: 1) != nil { completed += 1 }
   }
  }
  XCTAssertEqual(completed, 2)
  var expired = VeilopolyControlAssembler()
  XCTAssertNil(try expired.ingest(first[0], from: "host", now: 0))
  for fragment in first.dropFirst() { XCTAssertNil(try expired.ingest(fragment, from: "host", now: 301)) }
  XCTAssertNotNil(try expired.ingest(first[0], from: "host", now: 301))
 }
 func testInvalidFragmentBoundsAndConflictingDuplicateAreRejected() throws {
  var assembler = VeilopolyControlAssembler()
  let id = UUID().uuidString
  XCTAssertThrowsError(try assembler.ingest(.init(roomID: config.roomID, transferID: id,
   index: Int.max, count: 2, bytes: Data([1])), from: "host", now: 1))
  let first = VeilopolyControlFragment(roomID: config.roomID, transferID: id, index: 0, count: 2, bytes: Data([1]))
  XCTAssertNil(try assembler.ingest(first, from: "host", now: 1))
  XCTAssertThrowsError(try assembler.ingest(.init(roomID: config.roomID, transferID: id,
   index: 0, count: 2, bytes: Data([2])), from: "host", now: 1))
 }
}
