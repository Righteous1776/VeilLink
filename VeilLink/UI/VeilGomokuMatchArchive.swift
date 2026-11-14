import Foundation
import CryptoKit

/// Separate, append-only *per-match* history. Does not replace the existing
/// LocalBoardMatchStore latest-match recovery file or the training database.
/// Each match has its own UUID-named JSON file; there is NO fixed game-count cap.
final class VeilGomokuMatchArchive {
    enum Status: String, Codable, Sendable {
        case playing, humanWon, aiWon, draw, interrupted
        var isFinal: Bool { self != .playing }
        var title: String {
            switch self {
            case .playing: return "进行中"
            case .humanWon: return "玩家获胜"
            case .aiWon: return "ECLIPSE 获胜"
            case .draw: return "平局"
            case .interrupted: return "中断棋局"
            }
        }
    }

    struct Move: Codable, Hashable, Sendable {
        let index: Int
        /// 1 = black / host, 2 = white / guest.
        let stone: UInt8
        init(index: Int, stone: UInt8) { self.index = index; self.stone = stone }
    }

    struct Match: Codable, Sendable, Identifiable {
        static let version = 1
        let version: Int
        let id: String
        let startedAt: Date
        let updatedAt: Date
        let completedAt: Date?
        let status: Status
        let difficulty: String
        let humanStone: UInt8
        let moves: [Move]

        var placedMoves: [VeilEclipseTracePolicy.PlacedMove] {
            moves.map { .init(index: $0.index, stone: $0.stone) }
        }
        var isReplayable: Bool {
            !VeilEclipseTracePolicy.replayFrames(
                placedMoves,
                matchFinished: true,
                separateReadOnlyPanel: true
            ).isEmpty
        }
    }

    struct Page {
        let matches: [Match]
        let totalFiles: Int
        let nextOffset: Int?
        let invalidFiles: Int
    }

    enum ArchiveError: LocalizedError {
        case invalidSession, invalidMoves, conflict, corrupted, invalidStatus
        var errorDescription: String? {
            switch self {
            case .invalidSession: return "棋局编号无效，未保存。"
            case .invalidMoves: return "棋谱走子校验未通过，未覆盖原记录。"
            case .conflict: return "同一棋局的旧记录与新走子不一致，旧记录已保护。"
            case .corrupted: return "历史棋谱可能损坏，已保留原文件。"
            case .invalidStatus: return "棋局结果与棋盘不一致，未归档。"
            }
        }
    }

    let directory: URL
    private let manager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.manager = fileManager
        if let directory { self.directory = directory }
        else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directory = support
                .appendingPathComponent("VeilLink", isDirectory: true)
                .appendingPathComponent("GomokuMatchHistoryV1", isDirectory: true)
        }
    }

    private func canonicalID(_ sessionID: String) throws -> String {
        if let uuid = UUID(uuidString: sessionID) { return uuid.uuidString }
        // Older LocalBoardMatchStore records may have non-UUID session IDs.
        // Keep their original journal identity, but use a stable, traversal-safe
        // UUID surrogate solely as the ECLIPSE archive's filename and record ID.
        guard !sessionID.isEmpty, sessionID.count <= 128 else { throw ArchiveError.invalidSession }
        let input = Data(("VeilLink.GomokuMatchHistoryV1.legacy|" + sessionID).utf8)
        let digest = Array(SHA256.hash(data: input))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )).uuidString
    }

    private func url(for id: String) throws -> URL {
        directory.appendingPathComponent(try canonicalID(id) + ".json", isDirectory: false)
    }

    func read(sessionID: String) throws -> Match? {
        let path = try url(for: sessionID)
        guard manager.fileExists(atPath: path.path) else { return nil }
        // Bound untrusted/recovered archive bytes BEFORE decoding to prevent
        // oversized or malformed JSON from exhausting memory during pagination.
        let bytes = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard (1...128_000).contains(bytes) else { throw ArchiveError.corrupted }
        let data = try Data(contentsOf: path)
        guard let match = try? JSONDecoder().decode(Match.self, from: data),
              match.id == (try? canonicalID(sessionID)), validate(match) else {
            throw ArchiveError.corrupted
        }
        return match
    }

    /// Called after each *committed* player/AI move and when the actual result
    /// is known. A final match cannot be edited, replaced, or silently reset.
    @discardableResult
    func save(
        sessionID: String,
        moves: [Move],
        difficulty: String,
        humanStone: UInt8,
        status: Status,
        now: Date = Date()
    ) throws -> Match? {
        guard !moves.isEmpty else { return nil } // no phantom empty games
        let id = try canonicalID(sessionID)
        let prior = try read(sessionID: id)
        if let prior {
            guard prior.humanStone == humanStone,
                  prior.moves.count <= moves.count,
                  Array(moves.prefix(prior.moves.count)) == prior.moves else {
                throw ArchiveError.conflict
            }
            if prior.status.isFinal {
                // Retry after crash is safe; any alteration of final history is not.
                guard prior.status == status, prior.moves == moves else { throw ArchiveError.conflict }
                return prior
            }
        }
        // The device clock may move backwards; retain monotone archive dates.
        let effectiveNow = max(now, prior?.updatedAt ?? now)
        let match = Match(
            version: Match.version, id: id,
            startedAt: prior?.startedAt ?? now,
            updatedAt: effectiveNow,
            completedAt: status.isFinal ? effectiveNow : nil,
            status: status,
            difficulty: prior?.difficulty ?? difficulty,
            humanStone: humanStone, moves: moves
        )
        guard validate(match) else { throw ArchiveError.invalidMoves }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(match)
        guard data.count <= 128_000 else { throw ArchiveError.invalidMoves }
        var options: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try data.write(to: try url(for: id), options: options)
        return match
    }

    /// Paged listing reads only the requested slice, so old archives have no
    /// fixed match-count or storage cap and browsing remains bounded.
    func page(offset: Int = 0, limit: Int = 30) throws -> Page {
        guard manager.fileExists(atPath: directory.path) else {
            return Page(matches: [], totalFiles: 0, nextOffset: nil, invalidFiles: 0)
        }
        let files = try manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter {
            $0.pathExtension.lowercased() == "json"
                && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil
                && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a == b ? $0.lastPathComponent > $1.lastPathComponent : a > b
            }
        let start = min(max(0, offset), files.count)
        let end = min(files.count, start + min(100, max(1, limit)))
        var entries: [Match] = []
        var invalid = 0
        for url in files[start..<end] {
            do {
                if let item = try read(sessionID: url.deletingPathExtension().lastPathComponent) {
                    entries.append(item)
                }
            } catch { invalid += 1 } // Never delete or silently rewrite a corrupt record.
        }
        return Page(matches: entries, totalFiles: files.count,
                    nextOffset: end < files.count ? end : nil, invalidFiles: invalid)
    }

    private func validate(_ match: Match) -> Bool {
        guard match.version == Match.version,
              UUID(uuidString: match.id)?.uuidString == match.id,
              (1...2).contains(match.humanStone),
              !match.moves.isEmpty, match.moves.count <= 225,
              match.completedAt == nil || match.status.isFinal,
              match.status.isFinal == (match.completedAt != nil),
              match.updatedAt >= match.startedAt,
              (match.completedAt == nil || match.completedAt == match.updatedAt)
        else { return false }
        let frames = VeilEclipseTracePolicy.replayFrames(match.placedMoves,
            matchFinished: true, separateReadOnlyPanel: true)
        guard frames.count == match.moves.count + 1,
              let board = frames.last?.cells,
              let last = match.moves.last else { return false }
        let won = makesFive(board, index: last.index, stone: last.stone)
        switch match.status {
        case .humanWon: return won && last.stone == match.humanStone
        case .aiWon: return won && last.stone != match.humanStone
        case .draw: return !won && match.moves.count == 225
        case .interrupted: return !won && match.moves.count < 225
        case .playing: return true // last winning move may precede status finalization
        }
    }

    private func makesFive(_ board: [UInt8], index: Int, stone: UInt8) -> Bool {
        let row = index / 15, col = index % 15
        for (dr, dc) in [(1,0), (0,1), (1,1), (1,-1)] {
            var count = 1
            for sign in [-1,1] {
                var r = row + dr * sign, c = col + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), board[r*15+c] == stone {
                    count += 1; r += dr*sign; c += dc*sign
                }
            }
            if count >= 5 { return true }
        }
        return false
    }
}
