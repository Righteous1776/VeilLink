import Foundation
import VeilopolyEngine

/// P3 protocol-only continuation of a saved multiplayer match. GameTransport
/// remains unimplemented until authorized P5 host application integration.
/// The transport MUST authenticate the host and bind envelopes to gameID.
public enum MultiplayerResumeHandshake {
 /// A resumed client requests a trusted authoritative snapshot rather than
 /// accepting its own old guest checkpoint as the current game.
 public static func request(gameID: String, guest: GameState) -> GameEnvelope {
  GameEnvelope(gameId: gameID, kind: .resync,
               resync: ResyncRequest(afterSeq: guest.nextSeq - 1,
                                     observedHash: StateDigest.hash(guest)))
 }

 /// Host only answers requests from its authenticated game session. Refuses
 /// to roll a guest back if the guest claims more accepted moves than host.
 public static func hostResponse(_ request: GameEnvelope, host: GameState,
                                 expectedGameID: String) -> Result<GameEnvelope, GameSyncError> {
  guard !expectedGameID.isEmpty, request.gameId == expectedGameID
   else { return .failure(.sessionMismatch) }
  guard request.kind == .resync, let query = request.resync
   else { return .failure(.invalidMove) }
  let snapshot = GameSnapshot(host)
  guard query.afterSeq <= snapshot.lastAppliedSeq
   else { return .failure(.staleSnapshot) }
  // Preserve the existing P3 envelope format. P5 verifies peer identity.
  return .success(GameEnvelope(gameId: expectedGameID, kind: .snapshot,
                               snapshot: snapshot))
 }

 /// Accepts only the authenticated host's snapshot for the exact same match,
 /// without undoing an already committed local move or importing a different seed.
 public static func accept(_ response: GameEnvelope, currentGuest: GameState,
                           expectedGameID: String) -> Result<GameState, GameSyncError> {
  guard !expectedGameID.isEmpty, response.gameId == expectedGameID
   else { return .failure(.sessionMismatch) }
  guard response.kind == .snapshot, let snapshot = response.snapshot
   else { return .failure(.corruptSnapshot) }
  var replica = ReplicaClient(game: currentGuest)
  switch replica.resync(snapshot) {
  case .success: return .success(replica.game)
  case .failure(let error): return .failure(error)
  }
 }
}
