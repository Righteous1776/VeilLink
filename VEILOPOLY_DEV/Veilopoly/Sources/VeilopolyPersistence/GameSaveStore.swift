import Foundation
import VeilopolyEngine

/// App-local checkpoint storage. This never changes deterministic game rules.
public enum VeilopolySaveMode: String, Codable, Sendable {
 case solo, multiplayerHost, multiplayerGuest
}
public enum VeilopolySaveError: Error, Equatable {
 case invalidSession, invalidGameState, corruptCheckpoint, checkpointTooLarge
}
/// Lightweight UI receipt attached atomically to the SAME checked GameState slot.
/// It is deliberately not part of the deterministic network GameState.
public struct VeilopolyStockExecutionRecord: Codable, Equatable {
 public let id: Int
 public let symbol: String
 public let shares: Int
 public let priceCents: Int
 public let cashDelta: Int
 public let bought: Bool
 public let player: Int
 public init(id: Int, symbol: String, shares: Int, priceCents: Int,
             cashDelta: Int, bought: Bool, player: Int) {
  self.id=id; self.symbol=symbol; self.shares=shares; self.priceCents=priceCents
  self.cashDelta=cashDelta; self.bought=bought; self.player=player
 }
}
public struct VeilopolySavedGame: Codable, Equatable {
 public let schema: Int
 public let gameID: String
 public let mode: VeilopolySaveMode
 public let revision: UInt64
 public let savedAt: TimeInterval
 public let stateHash: String
 public let game: GameState
 /// Optional for old snapshots; a missing key must stay absent when
 /// re-encoding, or the legacy sealed checksum becomes invalid.
 public let stockReceipts: [VeilopolyStockExecutionRecord]?

 public init(schema: Int, gameID: String, mode: VeilopolySaveMode,
             revision: UInt64, savedAt: TimeInterval, stateHash: String,
             game: GameState, stockReceipts: [VeilopolyStockExecutionRecord]? = nil) {
  self.schema=schema; self.gameID=gameID; self.mode=mode
  self.revision=revision; self.savedAt=savedAt; self.stateHash=stateHash
  self.game=game; self.stockReceipts=stockReceipts
 }

 private enum CodingKeys: String, CodingKey {
  case schema, gameID, mode, revision, savedAt, stateHash, game, stockReceipts
 }
 public init(from decoder: Decoder) throws {
  let c=try decoder.container(keyedBy: CodingKeys.self)
  schema=try c.decode(Int.self, forKey: .schema)
  gameID=try c.decode(String.self, forKey: .gameID)
  mode=try c.decode(VeilopolySaveMode.self, forKey: .mode)
  revision=try c.decode(UInt64.self, forKey: .revision)
  savedAt=try c.decode(TimeInterval.self, forKey: .savedAt)
  stateHash=try c.decode(String.self, forKey: .stateHash)
  game=try c.decode(GameState.self, forKey: .game)
  stockReceipts=try c.decodeIfPresent([VeilopolyStockExecutionRecord].self, forKey: .stockReceipts)
 }
 public func encode(to encoder: Encoder) throws {
  var c=encoder.container(keyedBy: CodingKeys.self)
  try c.encode(schema, forKey: .schema)
  try c.encode(gameID, forKey: .gameID)
  try c.encode(mode, forKey: .mode)
  try c.encode(revision, forKey: .revision)
  try c.encode(savedAt, forKey: .savedAt)
  try c.encode(stateHash, forKey: .stateHash)
  try c.encode(game, forKey: .game)
  try c.encodeIfPresent(stockReceipts, forKey: .stockReceipts)
 }
}
private struct VeilopolySealedCheckpoint: Codable {
 let record: VeilopolySavedGame
 let checksum: String
}

/// Two alternating, independently checksummed JSON slots. A failed/interrupted
/// write cannot overwrite both generations. Data.write(.atomic) is best-effort
/// durability, not a hardware fsync or an unconditional power-loss guarantee.
/// Callers must serialize writes to a single game session.
public final class VeilopolySaveStore {
 private let directory: URL
 private let files: FileManager
 private let encoder: JSONEncoder
 private let decoder: JSONDecoder
 private static let maximumBytes = 48 * 1024 * 1024

 public init(directory: URL? = nil, files: FileManager = .default) throws {
  self.files = files
  let base: URL
  if let directory { base = directory }
  else {
   base = try files.url(for: .applicationSupportDirectory, in: .userDomainMask,
                        appropriateFor: nil, create: true)
    .appendingPathComponent("Veilopoly", isDirectory: true)
    .appendingPathComponent("Sessions", isDirectory: true)
  }
  try files.createDirectory(at: base, withIntermediateDirectories: true)
  self.directory = base
  self.encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  self.decoder = JSONDecoder()
 }

 private static func hexID(_ key: String) -> String {
  var value: UInt64 = 14_695_981_039_346_656_037
  for byte in key.utf8 { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
  let result = String(value, radix: 16)
  return String(repeating: "0", count: max(0, 16 - result.count)) + result
 }
 private func slots(gameID: String, mode: VeilopolySaveMode) throws -> [URL] {
  guard !gameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        gameID.utf8.count <= 128 else { throw VeilopolySaveError.invalidSession }
  let prefix = "veilo-\(mode.rawValue)-\(Self.hexID(gameID))"
  return [directory.appendingPathComponent(prefix + "-a.json"),
          directory.appendingPathComponent(prefix + "-b.json")]
 }
 private static func checksum(_ data: Data) -> String {
  var n: UInt64 = 14_695_981_039_346_656_037
  for byte in data { n = (n ^ UInt64(byte)) &* 1_099_511_628_211 }
  let result = String(n, radix: 16)
  return String(repeating: "0", count: max(0, 16 - result.count)) + result
 }
 private static func plausible(_ g: GameState) -> Bool {
  guard g.board.count == 40, g.players.count == 4,
        g.board.enumerated().allSatisfy({ i, t in
         t.i == i && (0...1_000_000).contains(t.price) &&
         (0...4).contains(t.houses) && (t.owner == nil || (0..<4).contains(t.owner!)) &&
         (t.kind != .street || t.rent.count == 6)
        }),
        g.players.enumerated().allSatisfy({ i, p in
         p.id == i && (0..<40).contains(p.position) && (0...1_000_000_000).contains(p.cash)
        }),
        g.nextSeq >= 0, g.moveLog.count == g.nextSeq,
        g.moveLog.enumerated().allSatisfy({ i, move in move.seq == i }),
        (0..<4).contains(g.turn.player),
        (0...32).contains(g.bank.houses), (0...12).contains(g.bank.hotels),
        (g.banking.map { IntegratedBanking.validate($0) } ?? true) else { return false }
  if let winner = g.winner {
   guard (0..<4).contains(winner), g.turn.phase == .finished,
         !g.players[winner].bankrupt else { return false }
  }
  return true
 }
 /// Accepted receipt IDs must describe committed moves of the SAME match.
 /// This refuses invented prices, wrong players and stale events from an old run.
 private static func plausibleReceipts(_ receipts: [VeilopolyStockExecutionRecord]?,
                                      game: GameState) -> Bool {
  guard let receipts else { return true }
  guard receipts.count <= 40 else { return false }
  var seen = Set<Int>()
  for r in receipts {
   guard r.id >= 0, game.moveLog.indices.contains(r.id),
         seen.insert(r.id).inserted, game.players.indices.contains(r.player),
         r.shares > 0, r.priceCents > 0,
         (-1_000_000_000...1_000_000_000).contains(r.cashDelta),
         (r.bought && r.cashDelta < 0) || (!r.bought && r.cashDelta > 0) else { return false }
   let move = game.moveLog[r.id]
   guard move.seq == r.id, move.player == r.player,
         move.type == (r.bought ? .stockBuy : .stockSell),
         move.stockSymbol == r.symbol, move.stockShares == r.shares else { return false }
  }
  return zip(receipts, receipts.dropFirst()).allSatisfy { $0.0.id > $0.1.id }
 }

 private func verified(_ data: Data, gameID: String, mode: VeilopolySaveMode) -> VeilopolySavedGame? {
  guard data.count <= Self.maximumBytes,
        let envelope = try? decoder.decode(VeilopolySealedCheckpoint.self, from: data),
        envelope.record.schema == 1, envelope.record.gameID == gameID,
        envelope.record.mode == mode, envelope.record.revision > 0,
        Self.plausible(envelope.record.game),
        Self.plausibleReceipts(envelope.record.stockReceipts, game: envelope.record.game),
        envelope.record.stateHash == StateDigest.hash(envelope.record.game),
        let plain = try? encoder.encode(envelope.record),
        envelope.checksum == Self.checksum(plain) else { return nil }
  return envelope.record
 }

 public func load(gameID: String, mode: VeilopolySaveMode) throws -> VeilopolySavedGame? {
  let paths = try slots(gameID: gameID, mode: mode)
  var valid: [VeilopolySavedGame] = []
  var found = false
  for path in paths {
   guard files.fileExists(atPath: path.path) else { continue }
   found = true
   guard let data = try? Data(contentsOf: path, options: .mappedIfSafe),
         let record = verified(data, gameID: gameID, mode: mode) else { continue }
   valid.append(record)
  }
  if let latest = valid.max(by: { $0.revision < $1.revision }) { return latest }
  if found { throw VeilopolySaveError.corruptCheckpoint }
  return nil
 }

 /// Only after an explicit user's destructive restart choice. Retains unreadable
 /// files in a quarantine folder so diagnostics remain possible.
 @discardableResult
 public func quarantineUnreadable(gameID: String, mode: VeilopolySaveMode) throws -> Bool {
  do { _ = try load(gameID: gameID, mode: mode); return false }
  catch VeilopolySaveError.corruptCheckpoint {
   let paths = try slots(gameID: gameID, mode: mode)
   let quarantine = directory.appendingPathComponent("Quarantine", isDirectory: true)
   try files.createDirectory(at: quarantine, withIntermediateDirectories: true)
   for path in paths where files.fileExists(atPath: path.path) {
    let destination = quarantine.appendingPathComponent(path.lastPathComponent + "." + UUID().uuidString + ".corrupt")
    try files.moveItem(at: path, to: destination)
   }
   return true
  }
 }

 @discardableResult
 public func save(_ game: GameState, gameID: String, mode: VeilopolySaveMode,
                  stockReceipts: [VeilopolyStockExecutionRecord]? = nil) throws -> VeilopolySavedGame {
  guard Self.plausible(game), Self.plausibleReceipts(stockReceipts, game: game)
   else { throw VeilopolySaveError.invalidGameState }
  let paths = try slots(gameID: gameID, mode: mode)
  let old = try load(gameID: gameID, mode: mode)
  let nextRevision: UInt64
  if let old {
   guard old.revision < UInt64.max else { throw VeilopolySaveError.invalidGameState }
   nextRevision = old.revision + 1
  } else { nextRevision = 1 }
  let record = VeilopolySavedGame(schema: 1, gameID: gameID, mode: mode,
                                 revision: nextRevision, savedAt: Date().timeIntervalSince1970,
                                 stateHash: StateDigest.hash(game), game: game,
                                 stockReceipts: stockReceipts)
  let plain = try encoder.encode(record)
  let sealed = VeilopolySealedCheckpoint(record: record, checksum: Self.checksum(plain))
  let data = try encoder.encode(sealed)
  guard data.count <= Self.maximumBytes else { throw VeilopolySaveError.checkpointTooLarge }
  let target = paths[Int((nextRevision - 1) % 2)]
  try data.write(to: target, options: .atomic)
  #if os(iOS)
  try? files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                          ofItemAtPath: target.path)
  #endif
  guard let written = try? Data(contentsOf: target, options: .mappedIfSafe),
        verified(written, gameID: gameID, mode: mode)?.revision == nextRevision else {
   throw VeilopolySaveError.corruptCheckpoint
  }
  return record
 }
}
