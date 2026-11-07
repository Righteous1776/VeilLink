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

 func testResumeRoundTripAndRoomBinding() throws {
  let g = GameFactory.make(seed: 707, humanCount: 2)
  let request = MultiplayerResumeHandshake.request(gameID: room, guest: g)
  let roundTripped = try XCTUnwrap(VeilopolyRoomWire.decode(VeilopolyRoomWire.encode(request)))
  XCTAssertEqual(request, roundTripped)
  XCTAssertNil(VeilopolyRoomWire.decode(try VeilopolyRoomWire.encode(
   GameEnvelope(gameId: room, kind: .accept)) + "tampered"))
 }
}
