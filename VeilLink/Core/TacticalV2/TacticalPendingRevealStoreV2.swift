import Foundation

extension TacticalV2 {
    enum PendingRevealStoreV2 {
        private static let prefix = "tactical.v2.pending-reveal."

        static func save(
            _ reveal: RevealV2,
            sessionID: String,
            defaults: UserDefaults = .standard
        ) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(reveal)
            defaults.set(data, forKey: key(sessionID: sessionID, turn: reveal.turn))
        }

        static func load(
            sessionID: String,
            turn: Int32,
            defaults: UserDefaults = .standard
        ) -> RevealV2? {
            guard let data = defaults.data(
                forKey: key(sessionID: sessionID, turn: turn)
            ) else {
                return nil
            }
            return try? JSONDecoder().decode(RevealV2.self, from: data)
        }

        static func remove(
            sessionID: String,
            turn: Int32,
            defaults: UserDefaults = .standard
        ) {
            defaults.removeObject(
                forKey: key(sessionID: sessionID, turn: turn)
            )
        }

        private static func key(
            sessionID: String,
            turn: Int32
        ) -> String {
            prefix + sessionID + "." + String(turn)
        }
    }
}
