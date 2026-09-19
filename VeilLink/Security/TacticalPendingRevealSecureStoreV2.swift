import CryptoKit
import Foundation

extension TacticalV2 {
    enum PendingRevealSecureStoreV2 {
        private static let service = "studio.zeo.veillink.tactical.v2.pending-reveal"
        private static let prefix = "turn."

        static func save(_ reveal: RevealV2, sessionID: String) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(reveal)
            try store().set(data, for: key(sessionID: sessionID, turn: reveal.turn))
        }

        static func load(sessionID: String, turn: Int32) -> RevealV2? {
            guard let data = store().data(for: key(sessionID: sessionID, turn: turn)) else { return nil }
            return try? JSONDecoder().decode(RevealV2.self, from: data)
        }

        static func remove(sessionID: String, turn: Int32) {
            store().remove(key(sessionID: sessionID, turn: turn))
        }

        private static func store() -> KeychainStore {
            KeychainStore(service: service)
        }

        private static func key(sessionID: String, turn: Int32) -> String {
            let digest = SHA256.hash(data: Data(sessionID.utf8))
            let sessionHash = digest.map { String(format: "%02x", $0) }.joined()
            return prefix + sessionHash + "." + String(turn)
        }
    }
}
