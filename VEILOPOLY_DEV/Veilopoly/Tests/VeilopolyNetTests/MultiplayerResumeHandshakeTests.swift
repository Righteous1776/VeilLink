import XCTest
import VeilopolyEngine
import VeilopolyNet

final class MultiplayerResumeHandshakeTests: XCTestCase {
 func testRequestCarriesSavedSeqAndDigest() {
  let game = GameFactory.make(seed: 2026)
  let message = MultiplayerResumeHandshake.request(gameID: "roomA", guest: game)
  XCTAssertEqual(message.gameId, "roomA")
  XCTAssertEqual(message.kind, .resync)
  XCTAssertEqual(message.resync?.afterSeq, -1)
  XCTAssertEqual(message.resync?.observedHash, StateDigest.hash(game))
 }
 func testTrustedNewerHostStateRestoresGuest() {
  let before = GameFactory.make(seed: 2026)
  var host = AuthoritativeHost(game: before)
  let move = Move(.rollDice, player: 0, seq: before.nextSeq)
  guard case .success = host.accept(move) else { return XCTFail("Host move rejected") }
  let request = MultiplayerResumeHandshake.request(gameID: "roomA", guest: before)
  guard case .success(let response) =
   MultiplayerResumeHandshake.hostResponse(request, host: host.game, expectedGameID: "roomA")
  else { return XCTFail("Expected host snapshot") }
  guard case .success(let recovered) =
   MultiplayerResumeHandshake.accept(response, currentGuest: before, expectedGameID: "roomA")
  else { return XCTFail("Unable to restore authoritative state") }
  XCTAssertEqual(recovered, host.game)
  XCTAssertEqual(StateDigest.hash(recovered), StateDigest.hash(host.game))
 }
 func testRejectsWrongRoomAndWrongSeed() {
  let before = GameFactory.make(seed: 2026)
  let request = MultiplayerResumeHandshake.request(gameID: "wrong", guest: before)
  guard case .failure(.sessionMismatch) =
   MultiplayerResumeHandshake.hostResponse(request, host: before, expectedGameID: "roomA")
  else { return XCTFail("Wrong room was accepted") }
  let response = GameEnvelope(gameId: "roomA", kind: .snapshot,
                              snapshot: GameSnapshot(GameFactory.make(seed: 2027)))
  guard case .failure(.sessionMismatch) =
   MultiplayerResumeHandshake.accept(response, currentGuest: before, expectedGameID: "roomA")
  else { return XCTFail("Wrong seed was accepted") }
 }
 func testRefusesGuestRollback() {
  let initial = GameFactory.make(seed: 2026)
  var host = AuthoritativeHost(game: initial)
  guard case .success = host.accept(Move(.rollDice, player: 0, seq: 0))
  else { return XCTFail("Host rejected roll") }
  let request = MultiplayerResumeHandshake.request(gameID: "roomA", guest: host.game)
  guard case .failure(.staleSnapshot) =
   MultiplayerResumeHandshake.hostResponse(request, host: initial, expectedGameID: "roomA")
  else { return XCTFail("Stale host could overwrite guest") }
  let older = GameEnvelope(gameId: "roomA", kind: .snapshot, snapshot: GameSnapshot(initial))
  guard case .failure(.staleSnapshot) =
   MultiplayerResumeHandshake.accept(older, currentGuest: host.game, expectedGameID: "roomA")
  else { return XCTFail("Old guest state was rolled back") }
 }
 func testRejectsTamperedHostDigest() {
  let game = GameFactory.make(seed: 2026)
  var tampered = game; tampered.nextSeq += 1 // count/log mismatch
  let response = GameEnvelope(gameId: "roomA", kind: .snapshot, snapshot: GameSnapshot(tampered))
  guard case .failure(.corruptSnapshot) =
   MultiplayerResumeHandshake.accept(response, currentGuest: game, expectedGameID: "roomA")
  else { return XCTFail("Corrupt snapshot was accepted") }
 }
}
