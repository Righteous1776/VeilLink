import Foundation
import VeilopolyEngine

/// First live topology: authenticated host + one guest, with two existing AI
/// seats. This is not a claim of four-device support or host migration.
public struct VeilopolyRoomConfiguration: Codable, Equatable {
 public let roomID: String
 public let seed: UInt64
 public let hostIdentityID: String
 public let guestIdentityID: String
 public init(roomID: String, seed: UInt64, hostIdentityID: String, guestIdentityID: String) {
  self.roomID = roomID; self.seed = seed
  self.hostIdentityID = hostIdentityID; self.guestIdentityID = guestIdentityID
 }
 public var isValid: Bool {
  UUID(uuidString: roomID)?.uuidString == roomID &&
  !hostIdentityID.isEmpty && !guestIdentityID.isEmpty &&
  hostIdentityID.utf8.count <= 128 && guestIdentityID.utf8.count <= 128 &&
  hostIdentityID != guestIdentityID
 }
 public func seat(for identity: String) -> Int? {
  identity == hostIdentityID ? 0 : (identity == guestIdentityID ? 1 : nil)
 }
}

public enum VeilopolyRoomPacketKind: String, Codable {
 case invite, accept, decline, proposal, commit, resync, snapshot, status, leave
}
public struct VeilopolyRoomPacket: Codable {
 public let version: Int
 public let roomID: String
 public let kind: VeilopolyRoomPacketKind
 public let configuration: VeilopolyRoomConfiguration?
 public let proposal: Move?
 public let committed: AuthoritativeMove?
 public let snapshot: GameSnapshot?
 public let nextSeq: Int?
 public let stateHash: String?
 public init(roomID: String, kind: VeilopolyRoomPacketKind,
             configuration: VeilopolyRoomConfiguration? = nil, proposal: Move? = nil,
             committed: AuthoritativeMove? = nil, snapshot: GameSnapshot? = nil,
             nextSeq: Int? = nil, stateHash: String? = nil) {
  version = 1; self.roomID = roomID; self.kind = kind; self.configuration = configuration
  self.proposal = proposal; self.committed = committed; self.snapshot = snapshot
  self.nextSeq = nextSeq; self.stateHash = stateHash
 }
 public var isValid: Bool {
  guard version == 1, UUID(uuidString: roomID)?.uuidString == roomID else { return false }
  let fields = [configuration != nil, proposal != nil, committed != nil, snapshot != nil,
                nextSeq != nil, stateHash != nil]
  switch kind {
  case .invite: return fields == [true,false,false,false,false,false] &&
    configuration?.isValid == true && configuration?.roomID == roomID
  case .proposal: return fields == [false,true,false,false,false,false]
  case .commit: return fields == [false,false,true,false,false,false]
  case .snapshot: return fields == [false,false,false,true,false,false]
  case .resync: return fields == [false,false,false,false,true,false] && (nextSeq ?? -1) >= 0
  case .status: return fields == [false,false,false,false,true,true] &&
    (nextSeq ?? -1) >= 0 && stateHash?.utf8.count == 16
  case .accept, .decline, .leave: return fields.allSatisfy { !$0 }
  }
 }
}

public enum VeilopolyRoomError: Error, Equatable {
 case invalidConfiguration, wrongPeer, wrongRoom, wrongRole, invalidPacket, invalidSnapshot
 case sequenceGap, hashMismatch, staleSnapshot, invalidProposal
}

/// Sole logical authority in a live session. UI mirrors committed states only.
/// Caller supplies sender identity from the existing authenticated E2EE channel,
/// NEVER from a JSON field. No transport/security/database dependency here.
public struct VeilopolyLiveRoom {
 public let configuration: VeilopolyRoomConfiguration
 public let localIdentityID: String
 public private(set) var game: GameState
 public var isHost: Bool { localIdentityID == configuration.hostIdentityID }
 public var localSeat: Int { isHost ? 0 : 1 }
 public var peerIdentityID: String { isHost ? configuration.guestIdentityID : configuration.hostIdentityID }
 public init(configuration: VeilopolyRoomConfiguration, localIdentityID: String,
             restoredGame: GameState? = nil) throws {
  guard configuration.isValid, configuration.seat(for: localIdentityID) != nil
   else { throw VeilopolyRoomError.invalidConfiguration }
  self.configuration = configuration; self.localIdentityID = localIdentityID
  let initial = restoredGame ?? GameFactory.make(seed: configuration.seed, humanCount: 2)
  guard Self.validSnapshotState(initial, configuration: configuration) else {
   throw VeilopolyRoomError.invalidSnapshot
  }
  game = initial
 }
 public func validate(_ packet: VeilopolyRoomPacket, from sender: String) throws {
  guard sender == peerIdentityID else { throw VeilopolyRoomError.wrongPeer }
  guard packet.roomID == configuration.roomID else { throw VeilopolyRoomError.wrongRoom }
  guard packet.isValid else { throw VeilopolyRoomError.invalidPacket }
 }
 public func validateProposal(_ move: Move, from sender: String) throws {
  guard isHost else { throw VeilopolyRoomError.wrongRole }
  guard sender == configuration.guestIdentityID, move.player == 1 else { throw VeilopolyRoomError.wrongPeer }
  guard ![MoveKind.applyMovement, .resolveTile, .stockTick].contains(move.type) else {
   throw VeilopolyRoomError.invalidProposal
  }
  guard move.seq == game.nextSeq else { throw VeilopolyRoomError.sequenceGap }
  let actor = game.auction?.turn ?? game.trade?.to ?? game.pendingDebt?.player ?? game.turn.player
  guard actor == 1, VeilopolyEngine.context(game).allowedMoves.contains(move.type) else {
   throw VeilopolyRoomError.invalidProposal
  }
 }
 public mutating func commitOnHost(_ move: Move) -> VeilopolyEngine.Transition {
  guard isHost else { return .failure(.notYourTurn) }
  let result = VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move)
  if case .success((let next, _)) = result { game = next }
  return result
 }
 public mutating func acceptCommit(_ committed: AuthoritativeMove, from sender: String) throws -> (GameState, [Effect]) {
  guard !isHost else { throw VeilopolyRoomError.wrongRole }
  guard sender == configuration.hostIdentityID else { throw VeilopolyRoomError.wrongPeer }
  guard committed.seq == game.nextSeq, committed.move.seq == committed.seq else {
   throw VeilopolyRoomError.sequenceGap
  }
  guard case .success((let next, let effects)) =
    VeilopolyEngine.apply(game, VeilopolyEngine.context(game), committed.move) else {
   throw VeilopolyRoomError.invalidProposal
  }
  guard StateDigest.hash(next) == committed.stateHash else { throw VeilopolyRoomError.hashMismatch }
  game = next
  return (next, effects)
 }
 public mutating func acceptSnapshot(_ snapshot: GameSnapshot, from sender: String) throws {
  guard !isHost else { throw VeilopolyRoomError.wrongRole }
  guard sender == configuration.hostIdentityID else { throw VeilopolyRoomError.wrongPeer }
  guard snapshot.game.nextSeq >= game.nextSeq else { throw VeilopolyRoomError.staleSnapshot }
  guard snapshot.game.moveLog.prefix(game.nextSeq).elementsEqual(game.moveLog) else {
   throw VeilopolyRoomError.invalidSnapshot // A higher sequence must not replace a different committed history.
  }
  guard Self.validSnapshotState(snapshot.game, configuration: configuration),
        snapshot.lastAppliedSeq == snapshot.game.nextSeq - 1,
        StateDigest.hash(snapshot.game) == snapshot.stateHash else { throw VeilopolyRoomError.invalidSnapshot }
  game = snapshot.game
 }
 public static func validSnapshotState(_ g: GameState, configuration: VeilopolyRoomConfiguration) -> Bool {
  guard g.seed == configuration.seed, g.players.count == 4, g.board.count == 40,
        g.nextSeq >= 0, g.moveLog.count == g.nextSeq,
        g.moveLog.enumerated().allSatisfy({ $0.offset == $0.element.seq }),
        g.players.enumerated().allSatisfy({ i, p in
         p.id == i && (0..<40).contains(p.position) && (0...1_000_000_000).contains(p.cash) &&
         (0...16).contains(p.chanceJailCards) && (0...16).contains(p.chestJailCards) &&
         p.jailTurns >= 0 && p.jailTurns < Int.max - 16 &&
         p.kind == (i < 2 ? .human : .ai)
        }), g.board.enumerated().allSatisfy({ i, t in
         t.i == i && (0...1_000_000).contains(t.price) && (0...1_000_000).contains(t.houseCost) &&
         (0...4).contains(t.houses) && (t.owner.map { (0..<4).contains($0) } ?? true) &&
         (t.kind != .street || t.rent.count == 6) && t.rent.allSatisfy({ (0...1_000_000).contains($0) })
        }), (0..<4).contains(g.turn.player), (0...12).contains(g.turn.pendingSteps),
        g.turn.rollCount >= 0 && g.turn.rollCount < Int.max - 16 &&
        g.turn.doubleCount >= 0 && g.turn.doubleCount < Int.max - 16,
        (g.turn.lastRoll.isEmpty || (g.turn.lastRoll.count == 2 && g.turn.lastRoll.allSatisfy({ (1...6).contains($0) }))),
        (g.turn.pendingPurchase.map { (0..<40).contains($0) } ?? true),
        (0...32).contains(g.bank.houses), (0...12).contains(g.bank.hotels),
        (g.banking.map { IntegratedBanking.validate($0) } ?? true) else { return false }
  let canonical = GameFactory.make(seed: configuration.seed, humanCount: 2)
  guard g.cards == canonical.cards,
        zip(g.board, canonical.board).allSatisfy({ tile, original in
         tile.kind == original.kind && tile.name == original.name && tile.color == original.color &&
         tile.price == original.price && tile.rent == original.rent && tile.houseCost == original.houseCost
        }), (g.banking.map { $0.terms == FinanceSandboxPolicy() } ?? true)
   else { return false } // Live v1 supports the canonical rules, not peer-injected paytables.
  for (deck, original) in [(g.chanceDeck, canonical.chanceDeck), (g.chestDeck, canonical.chestDeck)] {
   guard !deck.order.isEmpty, deck.cursor >= 0, deck.cursor < Int.max - 16,
         Set(deck.order).count == deck.order.count,
         deck.order.allSatisfy({ original.order.contains($0) }) else { return false }
  }
  if let a = g.auction {
   guard (0..<40).contains(a.tile), !a.active.isEmpty, a.active.count <= 4,
         Set(a.active).count == a.active.count, a.active.allSatisfy({ (0..<4).contains($0) }),
         a.active.contains(a.turn), (a.bidder.map { (0..<4).contains($0) } ?? true),
         (0...1_000_000_000).contains(a.currentBid) else { return false }
  }
  if let t = g.trade {
   guard (0..<4).contains(t.from), (0..<4).contains(t.to), t.from != t.to,
         [t.offer, t.request].allSatisfy({ transfer in
          (0...1_000_000_000).contains(transfer.cash) && transfer.tiles.allSatisfy({ (0..<40).contains($0) }) &&
          (0...16).contains(transfer.chanceCards) && (0...16).contains(transfer.chestCards)
         }) else { return false }
  }
  if let d = g.pendingDebt {
   guard (0..<4).contains(d.player), (d.creditor.map { (0..<4).contains($0) } ?? true),
         (0...1_000_000_000).contains(d.amount) else { return false }
  }
  if g.turn.phase == .auction && g.auction == nil { return false }
  if g.turn.phase == .trade && g.trade == nil { return false }
  if g.turn.phase == .debt && g.pendingDebt == nil { return false }
  if let winner = g.winner {
   guard (0..<4).contains(winner), g.turn.phase == .finished, !g.players[winner].bankrupt else { return false }
  }
  return true
 }
}
