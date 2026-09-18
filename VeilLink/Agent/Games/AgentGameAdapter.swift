import Foundation

struct AgentFeature: Codable, Hashable, Sendable {
    let key: String
    let value: Float
}

struct AgentGameObservation: Codable, Equatable, Sendable {
    let gameKind: MiniGameKind
    let gameVersion: String
    let stateHash: String
    let turn: Int
    let actor: MiniGamePlayer
    let features: [AgentFeature]
}

struct AgentActionCandidate: Codable, Hashable, Sendable {
    let actionID: String
    let encodedAction: Data
    let metadata: [String: String]
    let features: [AgentFeature]
}

protocol AgentGameAdapter {
    var gameKind: MiniGameKind { get }
    var adapterVersion: String { get }
    func makeObservation() -> AgentGameObservation
    func enumerateLegalActions() -> [AgentActionCandidate]
    func validate(_ action: AgentActionCandidate) -> Bool
}

enum AgentGameEncoding {
    static func stableHash(game: MiniGameKind, actor: MiniGamePlayer, features: [AgentFeature]) -> String {
        var hash: UInt64 = 1469598103934665603
        let prefix = "\(game.rawValue)|\(actor.rawValue)|"
        for byte in prefix.utf8 { hash ^= UInt64(byte); hash &*= 1099511628211 }
        for feature in features {
            for byte in feature.key.utf8 { hash ^= UInt64(byte); hash &*= 1099511628211 }
            var bits = feature.value.bitPattern.bigEndian
            withUnsafeBytes(of: &bits) { raw in
                for byte in raw { hash ^= UInt64(byte); hash &*= 1099511628211 }
            }
        }
        return String(format: "%016llx", hash)
    }

    static func encodeInts(_ values: [Int]) -> Data {
        Data(values.flatMap { value -> [UInt8] in
            let clamped = Int32(clamping: value).bigEndian
            return withUnsafeBytes(of: clamped) { Array($0) }
        })
    }
}
