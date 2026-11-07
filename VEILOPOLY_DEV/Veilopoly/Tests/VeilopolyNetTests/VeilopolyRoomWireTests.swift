import XCTest
import VeilopolyEngine
import VeilopolyNet

final class VeilopolyRoomWireTests: XCTestCase {
 private let room = "f6e37a89-1d60-46b1-bde8-0bad9c49c9e1"

 func testInviteAcceptAndDeclineRoundTrip() throws {
  let invite = GameInvite(gameId: room, seed: 707, humanSeats: [0, 1])
  let events = [
   GameEnvelope(gameId: room, kind: .invite, invite: invite),
   GameEnvelope(gameId: room, kind: .accept),
   GameEnvelope(gameId: room, kind: .decline)
  ]
  for item in events {
   XCTAssertEqual(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(item)), item)
  }
 }

 func testGuestIntentAndHostCommitRoundTrip() throws {
  let move = Move(.rollDice, player: 1, seq: 9)
  let intent = GameEnvelope(gameId: room, kind: .intent, intent: move)
  let committed = AuthoritativeMove(seq: move.seq, move: move, stateHash: "0123456789abcdef")
  let receipt = GameEnvelope(gameId: room, kind: .move, move: committed)
  XCTAssertEqual(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(intent)), intent)
  XCTAssertEqual(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(receipt)), receipt)
 }

 func testRejectsFabricatedSeatsAndWrongDirectionIntents() {
  let wrongSeats = GameInvite(gameId: room, seed: 515, humanSeats: [0, 2])
  XCTAssertFalse(VeilopolyRoomWire.isValid(GameEnvelope(gameId: room, kind: .invite, invite: wrongSeats)))
  XCTAssertFalse(VeilopolyRoomWire.isValid(GameEnvelope(
   gameId: room, kind: .intent, intent: Move(.buyProperty, player: 0, seq: 4, tile: 1))))
  XCTAssertFalse(VeilopolyRoomWire.isValid(GameEnvelope(
   gameId: room, kind: .intent, intent: Move(.buyProperty, player: 1, seq: -1, tile: 1))))
 }

 func testRejectsCorruptOrOversizedInputs() {
  XCTAssertNil(VeilopolyRoomWire.decode("not-game-data"))
  XCTAssertNil(VeilopolyRoomWire.decode(String(repeating: "x", count: VeilopolyRoomWire.maximumTextBytes + 1)))
  XCTAssertFalse(VeilopolyRoomWire.isValid(GameEnvelope(gameId: "not-uuid", kind: .accept)))
 }

 func testOnlyGuestMayAcceptAndHostMayCommit() {
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.invite,
   hostIsLocal: true, messageIsOutgoing: true))
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.accept,
   hostIsLocal: true, messageIsOutgoing: true))
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.accept,
   hostIsLocal: true, messageIsOutgoing: false))
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.intent,
   hostIsLocal: true, messageIsOutgoing: true))
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.intent,
   hostIsLocal: true, messageIsOutgoing: false))
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.move,
   hostIsLocal: false, messageIsOutgoing: false))
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.move,
   hostIsLocal: false, messageIsOutgoing: true))
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.snapshot,
   hostIsLocal: false, messageIsOutgoing: true))
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.resync,
   hostIsLocal: true, messageIsOutgoing: false))
 }

 func testTwoHumanSeatsProduceSameHostAndClientState() {
  let initial = GameFactory.make(seed: 90210, humanCount: 2)
  XCTAssertEqual(initial.players[0].kind, .human)
  XCTAssertEqual(initial.players[1].kind, .human)
  XCTAssertEqual(initial.players[2].kind, .ai)
  XCTAssertEqual(initial.players[3].kind, .ai)
  var authority = AuthoritativeHost(game: initial)
  var guest = ReplicaClient(game: initial)
  let move = Move(.rollDice, player: 0, seq: 0)
  guard case .success(let committed) = authority.accept(move) else {
   return XCTFail("host rejected valid opening roll")
  }
  guard case .success(let digest) = guest.replay(committed) else {
   return XCTFail("guest rejected authenticated host commit")
  }
  XCTAssertEqual(digest, StateDigest.hash(authority.game))
  XCTAssertEqual(guest.game, authority.game)
 }

 func testGuestReceivesHumanReadableHostRejection() throws {
  let event = GameEnvelope(gameId: room, kind: .rejected,
                           rejectedSeq: 12,
                           rejectionReason: "出价不能超过现金余额")
  let wire = try VeilopolyRoomWire.encode(event)
  XCTAssertEqual(VeilopolyRoomWire.decode(wire), event)
  XCTAssertNotNil(VeilopolyRoomWire.previewText(for: wire))
  XCTAssertTrue(VeilopolyRoomAuthorization.allows(.rejected,
   hostIsLocal: false, messageIsOutgoing: false))
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.rejected,
   hostIsLocal: false, messageIsOutgoing: true))
 }

 func testRejectsForgedHostRejectionOrOverlongReason() {
  XCTAssertFalse(VeilopolyRoomWire.isValid(
   GameEnvelope(gameId: room, kind: .rejected,
                rejectedSeq: nil, rejectionReason: "invalid")))
  XCTAssertFalse(VeilopolyRoomWire.isValid(
   GameEnvelope(gameId: room, kind: .rejected,
                rejectedSeq: 3, rejectionReason: String(repeating: "x", count: 241))))
  XCTAssertFalse(VeilopolyRoomWire.isValid(
   GameEnvelope(gameId: room, kind: .accept,
                rejectedSeq: 3, rejectionReason: "hidden rejection")))
 }

 func testHostResyncHintHasExactValidDirectionAndShape() throws {
  let event = GameEnvelope(gameId: room, kind: .syncHint, hostHeadSeq: 777)
  XCTAssertEqual(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(event)), event)
  XCTAssertFalse(VeilopolyRoomAuthorization.allows(.syncHint,
   hostIsLocal: true, messageIsOutgoing: false))
  XCTAssertFalse(VeilopolyRoomWire.isValid(
   GameEnvelope(gameId: room, kind: .syncHint,
                intent: Move(.rollDice, player: 1, seq: 1), hostHeadSeq: 4)))
 }

 func testResumeRoundTripAndRoomBinding() throws {
  let g = GameFactory.make(seed: 707, humanCount: 2)
  let request = MultiplayerResumeHandshake.request(gameID: room, guest: g)
  let roundTripped = try XCTUnwrap(VeilopolyRoomWire.decode(VeilopolyRoomWire.encode(request)))
  XCTAssertEqual(request, roundTripped)
  XCTAssertNil(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(
   GameEnvelope(gameId: room, kind: .accept)) + "tampered"))
 }
}
