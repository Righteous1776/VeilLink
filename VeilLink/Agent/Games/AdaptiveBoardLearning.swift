import Foundation

/// A game-scoped, on-device repertoire used by the native Gomoku and Xiangqi bots.
/// Every game and position is retained until the user explicitly clears it.
struct AdaptiveBoardLearningSnapshot: Sendable {
    static let empty = AdaptiveBoardLearningSnapshot(
        preferences: [:],
        rootAdjustments: [:],
        predictedHumanReplies: [:],
        trainingLevel: 0
    )

    fileprivate let preferences: [String: [String: Int]]
    fileprivate let rootAdjustments: [String: Int]
    fileprivate let predictedHumanReplies: [String: AdaptiveBoardPrediction]
    /// Bounded compute reinforcement derived from retained local evidence. This
    /// is independent of the uncapped on-disk history and is safe on old devices.
    let trainingLevel: Int

    func bonus(position: String, action: String) -> Int {
        preferences[position]?[action] ?? 0
    }

    /// Outcome-aware sequence memory. Repeating a line that lost (or was repeatedly
    /// abandoned) is penalised, while lines that held up are reinforced.
    func rootAdjustment(action: String) -> Int {
        rootAdjustments[action] ?? 0
    }

    /// The player's most likely next move after a candidate AI move.
    func predictedHumanReply(afterAIAction action: String) -> AdaptiveBoardPrediction? {
        predictedHumanReplies[action]
    }

    var hasSequenceEvidence: Bool {
        !rootAdjustments.isEmpty || !predictedHumanReplies.isEmpty
    }
}

struct AdaptiveBoardPrediction: Equatable, Sendable {
    let action: String
    let evidence: Int
}

struct DeveloperFormationInfluence: Sendable {
    static let empty = DeveloperFormationInfluence(rootAdjustments: [:], predictedHumanReplies: [:], matchedLessonNames: [])
    let rootAdjustments: [String: Int]
    let predictedHumanReplies: [String: AdaptiveBoardPrediction]
    let matchedLessonNames: [String]
}

extension AdaptiveBoardLearningSnapshot {
    func applying(_ influence: DeveloperFormationInfluence) -> AdaptiveBoardLearningSnapshot {
        var roots = rootAdjustments
        for (action, bonus) in influence.rootAdjustments {
            roots[action, default: 0] = min(2_400, max(-1_200, roots[action, default: 0] + bonus))
        }
        var replies = predictedHumanReplies
        for (action, prediction) in influence.predictedHumanReplies {
            if let current = replies[action], current.evidence > prediction.evidence { continue }
            replies[action] = prediction
        }
        return AdaptiveBoardLearningSnapshot(
            preferences: preferences,
            rootAdjustments: roots,
            predictedHumanReplies: replies,
            trainingLevel: trainingLevel
        )
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

/// A local, explainable training portrait. It is derived from the player's own
/// recorded games rather than a cloud rating or a black-box model.
struct PersonalBoardCoachProfile: Equatable, Sendable {
    let level: Int
    let completedGames: Int
    let repeatedLineCount: Int
    let preferredOpening: String
    let nextLesson: String
    /// A plain-language, evidence-based post-game direction. It is deliberately
    /// derived from local results rather than a remote rating or opaque model.
    let reviewFocus: String

    var levelText: String { "个性化教练 · Lv\(level)" }
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
        case .tooLarge: return "训练包大于当前设备可安全处理的可用空间。"
        case .unsupportedFormat: return "训练包版本不受支持。"
        case .checksumMismatch: return "训练包完整性校验失败。"
        case .invalidContent: return "训练包包含无效棋步或越界数据。"
        case .writeFailed: return "训练包通过校验，但无法保存到设备。"
        }
    }
}

@MainActor
final class AdaptiveBoardLearningStore {
    static let gomoku = AdaptiveBoardLearningStore(game: .gomoku)
    static let xiangqi = AdaptiveBoardLearningStore(game: .xiangqi)

    static func store(for game: MiniGameKind) -> AdaptiveBoardLearningStore {
        game == .xiangqi ? .xiangqi : .gomoku
    }

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

    private let fileURL: URL
    private let scopedGame: MiniGameKind?
    private var database: Database
    private(set) var lastSaveSucceeded = true
    /// Existing unreadable/invalid stores are retained on disk, never overwritten by autosave.
    private(set) var requiresRecovery = false

    init(game: MiniGameKind? = nil, fileURL: URL? = nil, legacyURL: URL? = nil) {
        let resolvedURL: URL
        if let fileURL {
            resolvedURL = fileURL
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("VeilLink", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let suffix = game == .xiangqi ? "xiangqi" : "gomoku"
            resolvedURL = root.appendingPathComponent("adaptive-board-learning-\(suffix)-v2.json")
        }
        self.fileURL = resolvedURL
        scopedGame = game
        let existingStore = FileManager.default.fileExists(atPath: resolvedURL.path)
        let loadedStore = Self.load(from: resolvedURL, scopedGame: game)
        database = loadedStore ?? Database()
        if existingStore && loadedStore == nil {
            requiresRecovery = true
            lastSaveSucceeded = false
        }

        // One-time, non-destructive migration from V27's shared store. The
        // legacy file is never moved, truncated or overwritten: each V2 game
        // database is fully encoded and decoded in a sibling temporary file
        // before its first atomic placement. A failed migration leaves the old
        // shared record available for retry on the next launch.
        let legacy = legacyURL ?? resolvedURL.deletingLastPathComponent()
            .appendingPathComponent("adaptive-board-learning-v1.json")
        if (fileURL == nil || legacyURL != nil),
           !FileManager.default.fileExists(atPath: resolvedURL.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            if let migrated = Self.load(from: legacy, scopedGame: game) {
                if !migrated.positions.isEmpty || !migrated.recentGames.isEmpty {
                    if Self.writeInitialMigration(migrated, to: resolvedURL) {
                        database = migrated
                        lastSaveSucceeded = true
                    } else {
                        lastSaveSucceeded = false
                    }
                }
            } else {
                // A corrupt legacy source is not silently replaced by an empty V2.
                requiresRecovery = true
                lastSaveSucceeded = false
            }
        }
    }

    var summary: AdaptiveBoardLearningSummary {
        // Metadata read only: the history is intentionally uncapped, so loading
        // its entire JSON just to display its byte count is a memory hazard.
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return AdaptiveBoardLearningSummary(
            completedGames: database.completedGames,
            rememberedPositions: database.positions.count,
            storedBytes: fileSize
        )
    }

    func snapshot(currentPlies: [AdaptiveBoardPly] = []) -> AdaptiveBoardLearningSnapshot {
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
        let sequence = currentPlies.map { ($0.actor == .host ? "h" : "a") + $0.action }
        var rootAdjustments: [String: Int] = [:]
        var replyEvidence: [String: [String: Int]] = [:]
        for record in database.recentGames where record.actions.starts(with: sequence) {
            guard record.actions.count > sequence.count else { continue }
            let next = record.actions[sequence.count]
            guard next.first == "a" else { continue }
            let aiAction = String(next.dropFirst())
            let outcome: Int
            switch record.result {
            case .aiWon: outcome = 420
            case .humanWon: outcome = -620
            case .draw: outcome = -60
            case .unfinished: outcome = -110
            }
            rootAdjustments[aiAction, default: 0] += outcome

            let humanIndex = sequence.count + 1
            if record.actions.indices.contains(humanIndex) {
                let reply = record.actions[humanIndex]
                if reply.first == "h" {
                    let action = String(reply.dropFirst())
                    let weight = record.result == .humanWon ? 4 : 1
                    replyEvidence[aiAction, default: [:]][action, default: 0] += weight
                }
            }
        }
        let predictions = replyEvidence.compactMapValues { actions -> AdaptiveBoardPrediction? in
            guard let best = actions.max(by: {
                $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
            }) else { return nil }
            return AdaptiveBoardPrediction(action: best.key, evidence: best.value)
        }
        return AdaptiveBoardLearningSnapshot(
            preferences: result,
            rootAdjustments: rootAdjustments.mapValues { min(1_200, max(-1_200, $0)) },
            predictedHumanReplies: predictions,
            trainingLevel: min(8, database.completedGames / 3 + database.positions.count / 220)
        )
    }

    func coachProfile(for game: MiniGameKind) -> PersonalBoardCoachProfile {
        let records = database.recentGames.filter { $0.game == game }
        let completed = records.filter { $0.result != .unfinished }.count
        let interrupted = records.filter { $0.result == .unfinished }.count
        let humanWins = records.filter { $0.result == .humanWon }.count
        let aiWins = records.filter { $0.result == .aiWon }.count
        // Count each opening once. The former max-by-filter implementation
        // rescanned the entire history for every comparison (quadratic cost).
        var openingCounts: [String: Int] = [:]
        for record in records {
            if let firstHumanMove = record.actions.first(where: { $0.first == "h" }) {
                let action = String(firstHumanMove.dropFirst())
                openingCounts[action, default: 0] += 1
            }
        }
        let repeatedLines = Dictionary(grouping: records) { record in
            record.actions.prefix(6).joined(separator: ",")
        }.values.filter { $0.count >= 2 }.count
        let preferredAction = openingCounts.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        })?.key

        let preferredOpening: String
        let nextLesson: String
        switch game {
        case .gomoku:
            if let action = preferredAction, let index = Int(action) {
                let row = index / GomokuState.size
                let column = index % GomokuState.size
                let center = GomokuState.size / 2
                preferredOpening = abs(row - center) <= 2 && abs(column - center) <= 2
                    ? "偏好中心起手"
                    : "偏好边侧起手"
            } else {
                preferredOpening = "正在观察你的起手"
            }
            nextLesson = repeatedLines > 0
                ? "下一课：复盘重复阵法中的活三、冲四与防守优先级。"
                : "下一课：先找对手的威胁，再决定进攻方向。"
        case .xiangqi:
            if preferredAction == "64:67" {
                preferredOpening = "偏好中炮"
            } else if preferredAction == "82:65" || preferredAction == "88:67" {
                preferredOpening = "偏好起马"
            } else if preferredAction != nil {
                preferredOpening = "偏好多变开局"
            } else {
                preferredOpening = "正在观察你的开局"
            }
            nextLesson = repeatedLines > 0
                ? "下一课：针对常用布局练习一手预防与两手反击。"
                : "下一课：发展子力前，先检查对方将军、吃子与威胁。"
        default:
            preferredOpening = "仅支持五子棋和中国象棋"
            nextLesson = "选择棋类对局后开始建立个人档案。"
        }
        let reviewFocus: String
        if interrupted >= max(2, completed) {
            reviewFocus = "复盘方向：中断局较多；先完成短对局，观察优势从哪一步开始丢失。"
        } else if aiWins > humanWins {
            reviewFocus = "复盘方向：重点回看电脑取得优势前的两手，先处理对方直接威胁。"
        } else if repeatedLines > 0 {
            reviewFocus = "复盘方向：你的常用线路已被识别；尝试为同一开局准备一个转向。"
        } else if humanWins > 0 {
            reviewFocus = "复盘方向：复走一局胜局，找出可以稳定复用的威胁与防守转换。"
        } else {
            reviewFocus = "复盘方向：先完成一局，教练会从开局、结果和重复线路生成针对性建议。"
        }
        let level = min(10, max(1, 1 + completed / 3 + database.positions.count / 180))
        return PersonalBoardCoachProfile(
            level: level,
            completedGames: completed,
            repeatedLineCount: repeatedLines,
            preferredOpening: preferredOpening,
            nextLesson: nextLesson,
            reviewFocus: reviewFocus
        )
    }

    func record(game: MiniGameKind, plies: [AdaptiveBoardPly], result: AdaptiveBoardGameResult) {
        guard game == .gomoku || game == .xiangqi, !plies.isEmpty else { return }
        guard scopedGame == nil || scopedGame == game else { return }
        guard !requiresRecovery else {
            lastSaveSucceeded = false
            return
        }

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
            database.positions[ply.position] = position
        }

        if result != .unfinished { database.completedGames += 1 }
        database.recentGames.append(GameRecord(
            game: game,
            result: result,
            actions: plies.map { ($0.actor == .host ? "h" : "a") + $0.action },
            finishedAt: Date()
        ))
        save()
    }

    func clear() {
        // Persist an empty scoped V2 database as an explicit migration tombstone.
        // Clear is the user's deliberate reset, including in recovery mode.
        let previous = database
        let previousRecovery = requiresRecovery
        database = Database()
        requiresRecovery = false
        save()
        if !lastSaveSucceeded {
            database = previous
            requiresRecovery = previousRecovery
        }
    }

    func exportPackage() throws -> URL {
        guard !requiresRecovery else { throw AdaptiveBoardLearningPackageError.invalidContent }
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let gameLabel = scopedGame == .xiangqi ? "Xiangqi" : "Gomoku"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLink-\(gameLabel)Learning-\(formatter.string(from: Date())).vltrain.json")
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
        let previousRecovery = requiresRecovery
        database = Self.filtered(envelope.payload, for: scopedGame)
        guard !database.positions.isEmpty || !database.recentGames.isEmpty else {
            database = previous
            throw AdaptiveBoardLearningPackageError.invalidContent
        }
        // Explicit validated package import is a permitted recovery operation.
        requiresRecovery = false
        save()
        guard lastSaveSucceeded else {
            database = previous
            requiresRecovery = previousRecovery
            throw AdaptiveBoardLearningPackageError.writeFailed
        }
        return AdaptiveBoardLearningImportReport(
            completedGames: database.completedGames,
            rememberedPositions: database.positions.count
        )
    }

    private func save() {
        guard !requiresRecovery else {
            lastSaveSucceeded = false
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(database)
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

    private static func load(from url: URL, scopedGame: MiniGameKind?) -> Database? {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Database.self, from: data),
              decoded.schema == 1,
              isValid(decoded) else { return nil }
        return filtered(decoded, for: scopedGame)
    }

    /// Writes an initial V2 database without touching the old shared file. The
    /// decode-back check prevents a half-written or wrongly-filtered migration
    /// from becoming the first durable store for either game.
    private static func writeInitialMigration(_ candidate: Database, to destination: URL) -> Bool {
        guard isValid(candidate),
              !FileManager.default.fileExists(atPath: destination.path) else { return false }
        let directory = destination.deletingLastPathComponent()
        let staging = directory.appendingPathComponent(
            ".\(destination.lastPathComponent).migrating-\(UUID().uuidString)"
        )
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(candidate)
            try data.write(to: staging, options: .atomic)
            guard let verificationData = try? Data(contentsOf: staging),
                  let verified = try? JSONDecoder().decode(Database.self, from: verificationData),
                  isValid(verified),
                  verified.positions.count == candidate.positions.count,
                  verified.recentGames.count == candidate.recentGames.count else {
                try? FileManager.default.removeItem(at: staging)
                return false
            }
            try FileManager.default.moveItem(at: staging, to: destination)
            return true
        } catch {
            try? FileManager.default.removeItem(at: staging)
            return false
        }
    }

    private static func filtered(_ database: Database, for game: MiniGameKind?) -> Database {
        guard let game else { return database }
        let prefix = game == .xiangqi ? "x:" : "g:"
        let positions = database.positions.filter { $0.key.hasPrefix(prefix) }
        let games = database.recentGames.filter { $0.game == game }
        return Database(
            schema: database.schema,
            completedGames: games.filter { $0.result != .unfinished }.count,
            sequence: database.sequence,
            positions: positions,
            recentGames: games
        )
    }

    private static func isValid(_ database: Database) -> Bool {
        guard database.completedGames >= 0,
              database.sequence >= 0 else { return false }
        for (position, stat) in database.positions {
            guard (position.hasPrefix("g:") || position.hasPrefix("x:")),
                  position.count <= 96 else { return false }
            for (action, value) in stat.actions {
                guard value.count > 0, value.count <= 65_535,
                      (-32_000...32_000).contains(value.aiReward),
                      isValid(action: action, for: position) else { return false }
            }
        }
        return database.recentGames.allSatisfy { record in
            (record.game == .gomoku || record.game == .xiangqi)
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
