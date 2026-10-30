import Combine
import CryptoKit
import Foundation

struct DeveloperFormationLesson: Codable, Identifiable, Equatable, Sendable {
    struct Move: Codable, Equatable, Sendable {
        let actor: MiniGamePlayer
        let action: String
    }

    let id: UUID
    let game: MiniGameKind
    let name: String
    let purpose: String
    let objective: String
    let moves: [Move]
    let createdAt: Date
}

@MainActor
final class DeveloperFormationLibrary: ObservableObject {
    @Published private(set) var lessons: [DeveloperFormationLesson] = []

    private struct Envelope: Codable {
        let schema: Int
        let lessons: [DeveloperFormationLesson]
        let mac: Data
    }

    private enum Key { static let mac = "board.developer-formations.mac.v1" }
    private let game: MiniGameKind
    private let keychain: KeychainStore
    private let fileURL: URL

    init(game: MiniGameKind, keychain: KeychainStore, fileURL: URL? = nil) {
        self.game = game
        self.keychain = keychain
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("VeilLink", isDirectory: true)
                .appendingPathComponent("DeveloperFormations", isDirectory: true)
            self.fileURL = root.appendingPathComponent("\(game.rawValue)-v1.json")
        }
        load()
    }

    func capture(name: String, purpose: String, objective: String, plies: [AdaptiveBoardPly]) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedObjective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...64).contains(trimmedName.count),
              (2...360).contains(trimmedPurpose.count),
              (2...240).contains(trimmedObjective.count),
              plies.count >= 2,
              plies.contains(where: { $0.actor == .guest }) else {
            throw DeveloperFormationError.invalidLesson
        }
        let lesson = DeveloperFormationLesson(
            id: UUID(),
            game: game,
            name: trimmedName,
            purpose: trimmedPurpose,
            objective: trimmedObjective,
            moves: plies.map { .init(actor: $0.actor, action: $0.action) },
            createdAt: Date()
        )
        lessons.append(lesson)
        do {
            try save()
        } catch {
            lessons.removeLast()
            throw error
        }
    }

    func remove(_ lesson: DeveloperFormationLesson) {
        let previous = lessons
        lessons.removeAll { $0.id == lesson.id }
        do { try save() } catch { lessons = previous }
    }

    func influence(for plies: [AdaptiveBoardPly]) -> DeveloperFormationInfluence {
        let current = plies.map { DeveloperFormationLesson.Move(actor: $0.actor, action: $0.action) }
        var roots: [String: Int] = [:]
        var replies: [String: AdaptiveBoardPrediction] = [:]
        var matchedNames: [String] = []
        for lesson in lessons where lesson.moves.starts(with: current) {
            guard lesson.moves.count > current.count else { continue }
            let nextIndex = current.count
            let next = lesson.moves[nextIndex]
            guard next.actor == .guest else { continue }
            matchedNames.append(lesson.name)
            roots[next.action, default: 0] += 1_400
            let replyIndex = nextIndex + 1
            if lesson.moves.indices.contains(replyIndex), lesson.moves[replyIndex].actor == .host {
                replies[next.action] = AdaptiveBoardPrediction(
                    action: lesson.moves[replyIndex].action,
                    evidence: 99
                )
            }
        }
        return DeveloperFormationInfluence(
            rootAdjustments: roots,
            predictedHumanReplies: replies,
            matchedLessonNames: matchedNames.sorted()
        )
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == 1,
              verify(envelope.lessons, mac: envelope.mac) else { return }
        lessons = envelope.lessons.filter { $0.game == game }
    }

    private func save() throws {
        let key = try macKey()
        let mac = Data(HMAC<SHA256>.authenticationCode(for: canonicalData(for: lessons), using: SymmetricKey(data: key)))
        let envelope = Envelope(schema: 1, lessons: lessons, mac: mac)
        let root = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(envelope).write(to: fileURL, options: .atomic)
    }

    private func verify(_ candidate: [DeveloperFormationLesson], mac: Data) -> Bool {
        // Verification must never manufacture a replacement key. If Keychain was
        // reset or is temporarily unavailable, the old on-disk lesson stays
        // untrusted instead of being silently re-keyed.
        do {
            guard let key = try keychain.readData(for: Key.mac), key.count == 32 else { return false }
            let expected = Data(HMAC<SHA256>.authenticationCode(for: canonicalData(for: candidate), using: SymmetricKey(data: key)))
            return expected == mac
        } catch {
            return false
        }
    }

    private func canonicalData(for candidate: [DeveloperFormationLesson]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(candidate)) ?? Data()
    }

    private func macKey() throws -> Data {
        if let current = try keychain.readData(for: Key.mac) {
            guard current.count == 32 else { throw DeveloperFormationError.keyUnavailable }
            return current
        }
        let key = PasswordKDF.randomData(count: 32)
        guard key.count == 32 else { throw DeveloperFormationError.keyUnavailable }
        try keychain.set(key, for: Key.mac)
        return key
    }
}

enum DeveloperFormationError: LocalizedError {
    case invalidLesson
    case keyUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidLesson: return "请录制至少两手、包含电脑应手的合法阵法，并填写名称、用途和目的。"
        case .keyUnavailable: return "无法取得本机阵法保护密钥。"
        }
    }
}
