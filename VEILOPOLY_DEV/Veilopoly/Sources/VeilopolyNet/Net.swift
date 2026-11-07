import Foundation
import VeilopolyEngine

/// Application payload types only: NO changes to VeilLink transport, protocol, or database.
public enum GameMessageType: String, Codable {
 case invite = "vl-game-invite"
 case accept = "vl-game-accept"
 case decline = "vl-game-decline"
 case intent = "vl-game-intent"
 case rejected = "vl-game-rejected"
 case move = "vl-game-move"
 case snapshot = "vl-game-snapshot"
 case resync = "vl-game-resync"
 case syncHint = "vl-game-sync-hint"
}
public struct AuthoritativeMove: Codable, Equatable {
 public let seq: Int
 public let move: Move
 public let stateHash: String
 public init(seq: Int, move: Move, stateHash: String) { self.seq = seq; self.move = move; self.stateHash = stateHash }
}
public struct GameSnapshot: Codable, Equatable {
 public let lastAppliedSeq: Int
 public let game: GameState
 public let stateHash: String
 public init(_ game: GameState) {
  self.lastAppliedSeq = game.nextSeq - 1; self.game = game; self.stateHash = StateDigest.hash(game)
 }
}
public struct GameInvite: Codable, Equatable {
 public var gameId: String
 public var seed: UInt64
 public var humanSeats: [Int]
 public init(gameId: String, seed: UInt64, humanSeats: [Int]) {
  self.gameId = gameId; self.seed = seed; self.humanSeats = humanSeats
 }
}
public struct ResyncRequest: Codable, Equatable {
 public let afterSeq: Int
 public let observedHash: String
 public init(afterSeq: Int, observedHash: String) { self.afterSeq = afterSeq; self.observedHash = observedHash }
}
public struct GameEnvelope: Codable, Equatable {
 public var gameId: String
 public var kind: GameMessageType
 public var invite: GameInvite?
 public var intent: Move?
 public var move: AuthoritativeMove?
 public var snapshot: GameSnapshot?
 public var resync: ResyncRequest?
 /// Last committed host sequence for bounded, multi-batch recovery.
 public var hostHeadSeq: Int?
 /// Host rejection for a guest's invalid/stale proposal. No game state changes.
 public var rejectedSeq: Int?
 public var rejectionReason: String?
 public init(gameId: String, kind: GameMessageType, invite: GameInvite? = nil,
             intent: Move? = nil, move: AuthoritativeMove? = nil,
             snapshot: GameSnapshot? = nil, resync: ResyncRequest? = nil,
             hostHeadSeq: Int? = nil, rejectedSeq: Int? = nil,
             rejectionReason: String? = nil) {
  self.gameId = gameId; self.kind = kind; self.invite = invite
  self.intent = intent
  self.move = move; self.snapshot = snapshot; self.resync = resync
  self.hostHeadSeq = hostHeadSeq
  self.rejectedSeq = rejectedSeq
  self.rejectionReason = rejectionReason
 }
}

/// An integration contract; production VeilLink app-layer adapter belongs to P5.
public protocol GameTransport {
 func send(_ payload: GameEnvelope) async throws
 func receive() -> AsyncThrowingStream<GameEnvelope, Error>
}

public enum GameSyncError: String, Error, Equatable {
 case seqGap, hashMismatch, invalidMove, corruptSnapshot, staleSnapshot, sessionMismatch
}
public struct AuthoritativeHost {
 public private(set) var game: GameState
 public private(set) var committed: [AuthoritativeMove]
 public init(game: GameState) { self.game = game; self.committed = [] }
 public mutating func accept(_ move: Move) -> Result<AuthoritativeMove, GameError> {
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move) {
  case .failure(let err): return .failure(err)
  case .success((let next, _)):
   game = next
   let authoritative = AuthoritativeMove(seq: move.seq, move: move, stateHash: StateDigest.hash(game))
   committed.append(authoritative)
   return .success(authoritative)
  }
 }
 public func missing(afterSeq: Int) -> [AuthoritativeMove] { committed.filter { $0.seq > afterSeq } }
 public func snapshot() -> GameSnapshot { GameSnapshot(game) }
}
public struct ReplicaClient {
 public private(set) var game: GameState
 public init(game: GameState) { self.game = game }
 public mutating func replay(_ packet: AuthoritativeMove) -> Result<String, GameSyncError> {
  guard packet.seq == game.nextSeq, packet.move.seq == packet.seq else { return .failure(.seqGap) }
  switch VeilopolyEngine.apply(game, VeilopolyEngine.context(game), packet.move) {
  case .failure: return .failure(.invalidMove)
  case .success((let next, _)):
   let computed = StateDigest.hash(next)
   guard computed == packet.stateHash else { return .failure(.hashMismatch) }
   game = next
   return .success(computed)
  }
 }
 public mutating func resync(_ snapshot: GameSnapshot) -> Result<String, GameSyncError> {
  // Snapshots are accepted only from the same seeded session. An older snapshot
  // must never silently roll a replica back after it has applied newer packets.
  // Same-sequence snapshots remain allowed to heal local divergence; the P5
  // transport adapter must authenticate the host and gameId before this call.
  guard snapshot.game.seed == game.seed else { return .failure(.sessionMismatch) }
  guard snapshot.game.nextSeq >= game.nextSeq else { return .failure(.staleSnapshot) }
  guard snapshot.game.nextSeq >= 0,
        snapshot.game.moveLog.count == snapshot.game.nextSeq,
        snapshot.game.moveLog.enumerated().allSatisfy({ $0.element.seq == $0.offset }),
        snapshot.lastAppliedSeq == snapshot.game.nextSeq - 1,
        StateDigest.hash(snapshot.game) == snapshot.stateHash else { return .failure(.corruptSnapshot) }
  game = snapshot.game
  return .success(snapshot.stateHash)
 }
}

/// Adapter is injected by the real VeilLink application using the authenticated
/// encrypted chat transport. The package never opens untrusted BLE sockets.
/// A zero-argument construction still fails CLOSED instead of fabricating a link.
public struct VeilLinkTransportAdapter: GameTransport {
 public typealias Sender = (GameEnvelope) async throws -> Void
 public typealias Receiver = () -> AsyncThrowingStream<GameEnvelope, Error>
 private let outbound: Sender
 private let inbound: Receiver

 public init(send: @escaping Sender, receive: @escaping Receiver) {
  outbound = send
  inbound = receive
 }

 public init() {
  outbound = { _ in throw P5IntegrationRequired.notIntegrated }
  inbound = {
   AsyncThrowingStream { continuation in
    continuation.finish(throwing: P5IntegrationRequired.notIntegrated)
   }
  }
 }

 public func send(_ payload: GameEnvelope) async throws {
  guard VeilopolyRoomWire.isValid(payload) else {
   throw VeilopolyRoomWire.CodecError.invalidShape
  }
  try await outbound(payload)
 }

 public func receive() -> AsyncThrowingStream<GameEnvelope, Error> { inbound() }
}
public enum P5IntegrationRequired: Error { case notIntegrated }
