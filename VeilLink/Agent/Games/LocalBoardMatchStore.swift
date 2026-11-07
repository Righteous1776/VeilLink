import Foundation

struct LocalBoardMatchMove: Codable, Equatable {
    let actor: MiniGamePlayer
    let move: MiniGameMove
}

struct LocalBoardMatchRecord: Codable {
    static let version = 1
    let version: Int
    let game: MiniGameKind
    let sessionID: String
    let difficulty: String
    let moves: [LocalBoardMatchMove]
    let humanPlayer: MiniGamePlayer?

    init(version: Int, game: MiniGameKind, sessionID: String, difficulty: String,
         moves: [LocalBoardMatchMove], humanPlayer: MiniGamePlayer? = nil) {
        self.version = version; self.game = game; self.sessionID = sessionID
        self.difficulty = difficulty; self.moves = moves; self.humanPlayer = humanPlayer
    }
}

struct LocalBoardMatchReplay {
    let gomoku: GomokuState
    let xiangqi: XiangqiState
    let plies: [AdaptiveBoardPly]

    static func validate(_ archive: LocalBoardMatchRecord) -> LocalBoardMatchReplay? {
        guard archive.version == LocalBoardMatchRecord.version,
              archive.game == .gomoku || archive.game == .xiangqi,
              !archive.sessionID.isEmpty, archive.sessionID.count <= 128,
              !archive.moves.isEmpty,
              archive.moves.count <= (archive.game == .gomoku ? 225 : 5_000)
        else { return nil }

        var gomoku = GomokuState()
        var xiangqi = XiangqiState()
        var plies: [AdaptiveBoardPly] = []
        plies.reserveCapacity(archive.moves.count)
        for event in archive.moves {
            guard event.move.piece == nil else { return nil }
            switch archive.game {
            case .gomoku:
                guard event.move.from == nil, let to = event.move.to else { return nil }
                let position = AdaptiveBoardPosition.gomoku(gomoku)
                guard gomoku.apply(index: to, actor: event.actor) else { return nil }
                plies.append(.init(position: position, action: String(to),
                                   actor: event.actor == (archive.humanPlayer ?? .host) ? .host : .guest))
            case .xiangqi:
                guard let from = event.move.from, let to = event.move.to else { return nil }
                let position = AdaptiveBoardPosition.xiangqi(xiangqi)
                guard xiangqi.apply(from: from, to: to, actor: event.actor) else { return nil }
                plies.append(.init(position: position, action: "\(from):\(to)",
                                   actor: event.actor == (archive.humanPlayer ?? .host) ? .host : .guest))
            default: return nil
            }
        }
        return .init(gomoku: gomoku, xiangqi: xiangqi, plies: plies)
    }
}

enum LocalBoardMatchStoreError: LocalizedError {
    case invalidArchive
    var errorDescription: String? { "棋局存档校验失败，旧文件已保留。" }
}

/// An independent, per-board-game move journal. Not a training archive.
final class LocalBoardMatchStore {
    let game: MiniGameKind
    let fileURL: URL

    init(game: MiniGameKind, directory: URL? = nil) {
        self.game = game
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let root = directory ?? support
            .appendingPathComponent("VeilLink", isDirectory: true)
            .appendingPathComponent("LocalMatchesV1", isDirectory: true)
        fileURL = root.appendingPathComponent("\(game.rawValue).json")
    }

    func load() throws -> LocalBoardMatchRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 1_000_000 else { throw LocalBoardMatchStoreError.invalidArchive }
        let bytes = try Data(contentsOf: fileURL)
        guard let saved = try? JSONDecoder().decode(LocalBoardMatchRecord.self, from: bytes),
              saved.game == game, LocalBoardMatchReplay.validate(saved) != nil else {
            throw LocalBoardMatchStoreError.invalidArchive
        }
        return saved
    }

    func save(_ record: LocalBoardMatchRecord) throws {
        guard record.game == game, LocalBoardMatchReplay.validate(record) != nil else {
            throw LocalBoardMatchStoreError.invalidArchive
        }
        let bytes = try JSONEncoder().encode(record)
        guard bytes.count <= 1_000_000 else { throw LocalBoardMatchStoreError.invalidArchive }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try bytes.write(to: fileURL, options: [
            .atomic, .completeFileProtectionUntilFirstUserAuthentication
        ])
    }

    /// Never delete corrupt evidence without first copying it aside.
    func discardOnExplicitRestart() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do { _ = try load() }
        catch {
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent(
                "\(game.rawValue)-recovery-\(UUID().uuidString).json"
            )
            try FileManager.default.copyItem(at: fileURL, to: backup)
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
