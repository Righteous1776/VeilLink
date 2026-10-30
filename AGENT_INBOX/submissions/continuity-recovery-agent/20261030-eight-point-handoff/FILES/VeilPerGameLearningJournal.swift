import Foundation

/// Independent append-only training evidence files (one for Gomoku, one
/// for Xiangqi). There is no fixed total-position, game-count or file-byte cap.
/// Reads are streamed to avoid loading the entire history on older devices.
/// This storage candidate does NOT automatically migrate/erase legacy v1 data.
struct VeilPerGameLearningJournal {
    typealias Engine = VeilFormationSequenceEngine
    enum JournalError: Error, LocalizedError {
        case damagedRecord, invalidGame, unavailable, unsafeSource, oversizedRecord
        var errorDescription: String? {
            switch self {
            case .damagedRecord: return "训练数据存在损坏记录，请先导出原始文件再处理。"
            case .invalidGame: return "此训练包属于另一种棋类，无法覆盖本棋谱库。"
            case .unavailable: return "无法创建或读取本地棋谱库。"
            case .unsafeSource: return "训练包必须是本地普通文件。"
            case .oversizedRecord: return "单局棋谱记录异常过大，已中止。"
            }
        }
    }
    struct Summary: Equatable {
        let episodes: Int
        let wins: Int
        let losses: Int
        let draws: Int
        let interruptions: Int
        let bytes: Int64
    }
    private struct Line: Codable {
        let format: String
        let episode: Engine.Episode
        let recordedAt: Date
    }

    let directory: URL
    init(directory: URL) { self.directory = directory }

    func url(for game: Engine.Game) -> URL {
        directory.appendingPathComponent("training-\(game.rawValue).jsonl")
    }

    func append(_ episode: Engine.Episode) throws {
        guard !episode.plies.isEmpty, episode.plies.count <= 600,
              episode.plies.allSatisfy({ !$0.action.isEmpty && $0.action.utf8.count <= 24 }) else {
            throw JournalError.oversizedRecord
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = self.url(for: episode.game)
        let line = Line(format: "veillink.learning.episode.v2", episode: episode, recordedAt: Date())
        var data = try JSONEncoder().encode(line)
        guard data.count <= 65_536 else { throw JournalError.oversizedRecord }
        data.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw JournalError.unavailable
            }
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    /// Streaming decoder: only the current JSON line is held in memory.
    func forEach(_ game: Engine.Game, _ body: (Engine.Episode) throws -> Void) throws {
        let file = url(for: game)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var remaining = Data()
        while true {
            let chunk = try handle.read(upToCount: 32_768) ?? Data()
            if chunk.isEmpty {
                guard remaining.isEmpty else { throw JournalError.damagedRecord }
                break
            }
            var begin = chunk.startIndex
            for index in chunk.indices where chunk[index] == 0x0A {
                remaining.append(chunk[begin..<index])
                guard remaining.count <= 65_536 else { throw JournalError.oversizedRecord }
                let value: Line
                do { value = try JSONDecoder().decode(Line.self, from: remaining) }
                catch { throw JournalError.damagedRecord }
                guard value.format == "veillink.learning.episode.v2",
                      value.episode.game == game else { throw JournalError.invalidGame }
                try body(value.episode)
                remaining.removeAll(keepingCapacity: true)
                begin = chunk.index(after: index)
            }
            remaining.append(contentsOf: chunk[begin...])
            if remaining.count > 65_536 { throw JournalError.oversizedRecord }
        }
    }

    func summary(for game: Engine.Game) throws -> Summary {
        var episodes = 0, wins = 0, losses = 0, draws = 0, interruptions = 0
        try forEach(game) { episode in
            episodes += 1
            switch episode.outcome {
            case .aiWon: wins += 1
            case .humanWon: losses += 1
            case .draw: draws += 1
            case .unfinished: interruptions += 1
            }
        }
        let values = try? url(for: game).resourceValues(forKeys: [.fileSizeKey])
        return Summary(episodes: episodes, wins: wins, losses: losses,
                       draws: draws, interruptions: interruptions,
                       bytes: Int64(values?.fileSize ?? 0))
    }

    func export(for game: Engine.Game) throws -> URL {
        // Independent original journal is never shared directly. Export an owned
        // temporary copy for Files/ShareSheet with the game name in the file name.
        let source = url(for: game)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLink-\(game.rawValue)-\(UUID().uuidString).vltrain.jsonl")
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: output)
        } else {
            try Data().write(to: output, options: .atomic)
        }
        return output
    }

    /// Does NOT mutate the other game file.
    func clear(_ game: Engine.Game) throws {
        let file = url(for: game)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    /// Import exactly one game's journal with validation and rollback.
    /// A user-selected Files URL is coordinated before leaving its scope;
    /// no other game's journal file is touched.
    func importJournal(from source: URL, for game: Engine.Game) throws -> Summary {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let checked = VeilPerGameLearningJournal(directory: staging)
        let candidate = checked.url(for: game)
        try VeilFilesIngress.withRead(from: source, maximumBytes: Int64.max) { readable in
            try FileManager.default.copyItem(at: readable, to: candidate)
        }
        let summary = try checked.summary(for: game)
        let current = url(for: game)
        let rollback = staging.appendingPathComponent("rollback-\(game.rawValue).jsonl")
        if FileManager.default.fileExists(atPath: current.path) {
            try FileManager.default.copyItem(at: current, to: rollback)
        }
        do {
            if FileManager.default.fileExists(atPath: current.path) {
                try FileManager.default.removeItem(at: current)
            }
            try FileManager.default.moveItem(at: candidate, to: current)
            return summary
        } catch {
            if FileManager.default.fileExists(atPath: rollback.path) {
                try? FileManager.default.removeItem(at: current)
                try? FileManager.default.copyItem(at: rollback, to: current)
            }
            throw error
        }
    }
}
