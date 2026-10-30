import Foundation

/// A compact, on-device repertoire used by the native Gomoku and Xiangqi bots.
/// It stores bounded action statistics plus a short rolling game history; no model
/// weights, network access, or unbounded database growth are involved.
struct AdaptiveBoardLearningSnapshot: Sendable {
    static let empty = AdaptiveBoardLearningSnapshot(preferences: [:])

    fileprivate let preferences: [String: [String: Int]]

    func bonus(position: String, action: String) -> Int {
        preferences[position]?[action] ?? 0
    }
}

enum AdaptiveBoardPosition {
    static func gomoku(_ state: GomokuState) -> String {
        var bytes: [UInt8] = [state.currentPlayer == .host ? 1 : 2]
        bytes.reserveCapacity(GomokuState.size * GomokuState.size + 1)
        for index in 0..<(GomokuState.size * GomokuState.size) {
            bytes.append(UInt8(state.value(at: index)))
        }
        return "g:" + fnv64(bytes)
    }

    static func xiangqi(_ state: XiangqiState) -> String {
        var bytes: [UInt8] = [state.currentPlayer == .host ? 1 : 2]
        bytes.reserveCapacity(XiangqiState.rows * XiangqiState.columns + 1)
        for index in 0..<(XiangqiState.rows * XiangqiState.columns) {
            guard let piece = state.piece(at: index) else {
                bytes.append(0)
                continue
            }
            let side: UInt8 = piece.side == .red ? 0 : 8
            let kind: UInt8
            switch piece.kind {
            case .general: kind = 1
            case .advisor: kind = 2
            case .elephant: kind = 3
            case .horse: kind = 4
            case .rook: kind = 5
            case .cannon: kind = 6
            case .soldier: kind = 7
            }
            bytes.append(side + kind)
        }
        return "x:" + fnv64(bytes)
    }

    private static func fnv64(_ bytes: [UInt8]) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return String(value, radix: 16)
    }
}

struct AdaptiveBoardPly: Equatable, Sendable {
    let position: String
    let action: String
    let actor: MiniGamePlayer
}

enum AdaptiveBoardGameResult: String, Codable, Sendable {
    case humanWon
    case aiWon
    case draw
    case unfinished

    fileprivate var aiReward: Int {
        switch self {
        case .aiWon: return 2
        case .humanWon: return -2
        case .draw, .unfinished: return 0
        }
    }
}

struct AdaptiveBoardLearningSummary: Equatable, Sendable {
    let completedGames: Int
    let rememberedPositions: Int
    let storedBytes: Int

    var compactText: String {
        "已学 \(completedGames) 局 · \(rememberedPositions) 个局面"
    }
}

struct AdaptiveBoardLearningImportReport: Equatable, Sendable {
    let completedGames: Int
    let rememberedPositions: Int
}

enum AdaptiveBoardLearningPackageError: LocalizedError, Equatable {
    case unreadable
    case tooLarge
    case unsupportedFormat
    case checksumMismatch
    case invalidContent
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取训练包。"
        case .tooLarge: return "训练包超过 1 MB 安全上限。"
        case .unsupportedFormat: return "训练包版本不受支持。"
        case .checksumMismatch: return "训练包完整性校验失败。"
        case .invalidContent: return "训练包包含无效棋步或越界数据。"
        case .writeFailed: return "训练包通过校验，但无法保存到设备。"
        }
    }
}

@MainActor
final class AdaptiveBoardLearningStore {
    static let shared = AdaptiveBoardLearningStore()

    private struct ActionStat: Codable {
        var count: Int
        var aiReward: Int
    }

    private struct PositionStat: Codable {
        var actor: MiniGamePlayer
        var actions: [String: ActionStat]
        var lastSequence: Int
    }

    private struct GameRecord: Codable {
        let game: MiniGameKind
        let result: AdaptiveBoardGameResult
        let actions: [String]
        let finishedAt: Date
    }

    private struct Database: Codable {
        var schema = 1
        var completedGames = 0
        var sequence = 0
        var positions: [String: PositionStat] = [:]
        var recentGames: [GameRecord] = []
    }

    private struct ExportEnvelope: Codable {
        let format: String
        let createdAt: Date
        let appVersion: String
        let checksumAlgorithm: String
        let payloadChecksum: String
        let payload: Database
    }

    private static let maximumPositions = 1_600
    private static let maximumActionsPerPosition = 8
    private static let maximumRecentGames = 40
    private static let maximumBytes = 512 * 1_024

    private let fileURL: URL
    private var database: Database
    private(set) var lastSaveSucceeded = true

    init(fileURL: URL? = nil) {
        let resolvedURL: URL
        if let fileURL {
            resolvedURL = fileURL
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("VeilLink", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            resolvedURL = root.appendingPathComponent("adaptive-board-learning-v1.json")
        }
        self.fileURL = resolvedURL
        database = Self.load(from: resolvedURL)
    }

    var summary: AdaptiveBoardLearningSummary {
        AdaptiveBoardLearningSummary(
            completedGames: database.completedGames,
            rememberedPositions: database.positions.count,
            storedBytes: (try? Data(contentsOf: fileURL).count) ?? 0
        )
    }

    func snapshot() -> AdaptiveBoardLearningSnapshot {
        var result = Self.seedPreferences()
        for (position, stat) in database.positions {
            var actions = result[position] ?? [:]
            for (action, actionStat) in stat.actions {
                let raw: Int
                if stat.actor == .guest {
                    // Reinforce AI moves that held up well, but keep the learned
                    // bonus below tactical wins and forced blocks.
                    raw = actionStat.count * 18 + actionStat.aiReward * 55
                } else {
                    // Human moves are predictions used for move ordering. Moves
                    // that beat the bot receive a little more attention.
                    raw = actionStat.count * 42 + max(0, -actionStat.aiReward) * 20
                }
                actions[action] = max(actions[action] ?? 0, min(900, max(-180, raw)))
            }
            result[position] = actions
        }
        return AdaptiveBoardLearningSnapshot(preferences: result)
    }

    func record(game: MiniGameKind, plies: [AdaptiveBoardPly], result: AdaptiveBoardGameResult) {
        guard game == .gomoku || game == .xiangqi, !plies.isEmpty else { return }

        database.sequence += 1
        let sequence = database.sequence
        for ply in plies {
            var position = database.positions[ply.position]
                ?? PositionStat(actor: ply.actor, actions: [:], lastSequence: sequence)
            var action = position.actions[ply.action] ?? ActionStat(count: 0, aiReward: 0)
            action.count = min(65_535, action.count + 1)
            action.aiReward = max(-32_000, min(32_000, action.aiReward + result.aiReward))
            position.actions[ply.action] = action
            position.lastSequence = sequence
            if position.actions.count > Self.maximumActionsPerPosition {
                let keep = position.actions.sorted { lhs, rhs in
                    if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                    return lhs.key < rhs.key
                }.prefix(Self.maximumActionsPerPosition)
                position.actions = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
            }
            database.positions[ply.position] = position
        }

        if result != .unfinished { database.completedGames += 1 }
        database.recentGames.append(GameRecord(
            game: game,
            result: result,
            actions: plies.map { ($0.actor == .host ? "h" : "a") + $0.action },
            finishedAt: Date()
        ))
        prune(positionLimit: Self.maximumPositions, historyLimit: Self.maximumRecentGames)
        save()
    }

    func clear() {
        database = Database()
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            lastSaveSucceeded = true
        } catch {
            lastSaveSucceeded = false
        }
    }

    func exportPackage() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let compactEncoder = JSONEncoder()
        compactEncoder.outputFormatting = [.sortedKeys]
        let payloadData = try compactEncoder.encode(database)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let envelope = ExportEnvelope(
            format: "veillink.board-learning.export.v1",
            createdAt: Date(),
            appVersion: version,
            checksumAlgorithm: "fnv1a64-canonical-json",
            payloadChecksum: Self.checksum(payloadData),
            payload: database
        )
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumBytes * 2 else { throw AdaptiveBoardLearningPackageError.tooLarge }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLink-BoardLearning-\(formatter.string(from: Date())).vltrain.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw AdaptiveBoardLearningPackageError.writeFailed
        }
    }

    func importPackage(from url: URL) throws -> AdaptiveBoardLearningImportReport {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            throw AdaptiveBoardLearningPackageError.unreadable
        }
        guard data.count <= Self.maximumBytes * 2 else {
            throw AdaptiveBoardLearningPackageError.tooLarge
        }
        guard let envelope = try? JSONDecoder().decode(ExportEnvelope.self, from: data),
              envelope.format == "veillink.board-learning.export.v1",
              envelope.checksumAlgorithm == "fnv1a64-canonical-json",
              envelope.payload.schema == 1 else {
            throw AdaptiveBoardLearningPackageError.unsupportedFormat
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let payloadData = try? encoder.encode(envelope.payload),
              Self.checksum(payloadData) == envelope.payloadChecksum else {
            throw AdaptiveBoardLearningPackageError.checksumMismatch
        }
        guard Self.isValid(envelope.payload) else {
            throw AdaptiveBoardLearningPackageError.invalidContent
        }

        let previous = database
        database = envelope.payload
        prune(positionLimit: Self.maximumPositions, historyLimit: Self.maximumRecentGames)
        save()
        guard lastSaveSucceeded else {
            database = previous
            throw AdaptiveBoardLearningPackageError.writeFailed
        }
        return AdaptiveBoardLearningImportReport(
            completedGames: database.completedGames,
            rememberedPositions: database.positions.count
        )
    }

    private func prune(positionLimit: Int, historyLimit: Int) {
        if database.positions.count > positionLimit {
            let keep = database.positions.sorted { lhs, rhs in
                if lhs.value.lastSequence != rhs.value.lastSequence {
                    return lhs.value.lastSequence > rhs.value.lastSequence
                }
                return lhs.key < rhs.key
            }.prefix(positionLimit)
            database.positions = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        if database.recentGames.count > historyLimit {
            database.recentGames.removeFirst(database.recentGames.count - historyLimit)
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            var data = try encoder.encode(database)
            if data.count > Self.maximumBytes {
                prune(positionLimit: Self.maximumPositions / 2, historyLimit: Self.maximumRecentGames / 2)
                data = try encoder.encode(database)
            }
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            lastSaveSucceeded = true
        } catch {
            lastSaveSucceeded = false
        }
    }

    private static func load(from url: URL) -> Database {
        guard let data = try? Data(contentsOf: url), data.count <= maximumBytes * 2,
              let decoded = try? JSONDecoder().decode(Database.self, from: data),
              decoded.schema == 1 else { return Database() }
        return decoded
    }

    private static func isValid(_ database: Database) -> Bool {
        guard database.completedGames >= 0,
              database.sequence >= 0,
              database.positions.count <= maximumPositions,
              database.recentGames.count <= maximumRecentGames else { return false }
        for (position, stat) in database.positions {
            guard (position.hasPrefix("g:") || position.hasPrefix("x:")),
                  position.count <= 32,
                  stat.actions.count <= maximumActionsPerPosition else { return false }
            for (action, value) in stat.actions {
                guard value.count > 0, value.count <= 65_535,
                      (-32_000...32_000).contains(value.aiReward),
                      isValid(action: action, for: position) else { return false }
            }
        }
        return database.recentGames.allSatisfy { record in
            (record.game == .gomoku || record.game == .xiangqi)
                && record.actions.count <= 225
                && record.actions.allSatisfy { $0.count <= 12 }
        }
    }

    private static func isValid(action: String, for position: String) -> Bool {
        if position.hasPrefix("g:") {
            guard let index = Int(action) else { return false }
            return (0..<(GomokuState.size * GomokuState.size)).contains(index)
        }
        let parts = action.split(separator: ":")
        guard parts.count == 2, let from = Int(parts[0]), let to = Int(parts[1]) else { return false }
        let range = 0..<(XiangqiState.rows * XiangqiState.columns)
        return range.contains(from) && range.contains(to) && from != to
    }

    private static func checksum(_ data: Data) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return String(value, radix: 16)
    }

    private static func seedPreferences() -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]

        var gomoku = GomokuState()
        if gomoku.apply(index: 112, actor: .host) {
            result[AdaptiveBoardPosition.gomoku(gomoku)] = ["111": 150, "113": 150, "97": 140, "127": 140]
        }

        var centralCannon = XiangqiState()
        if centralCannon.apply(from: 64, to: 67, actor: .host) {
            result[AdaptiveBoardPosition.xiangqi(centralCannon)] = ["19:22": 180, "1:20": 130]
        }

        var horseOpening = XiangqiState()
        if horseOpening.apply(from: 82, to: 65, actor: .host) {
            result[AdaptiveBoardPosition.xiangqi(horseOpening)] = ["1:20": 170]
        }
        return result
    }
}
