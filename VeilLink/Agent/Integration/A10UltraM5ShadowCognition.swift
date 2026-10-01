import CryptoKit
import Foundation

struct A10UltraM5ShadowCognitionSnapshot: Equatable, Sendable {
    let evaluatedAt: Date
    let runtimeID: String
    let outputDigest: String
    let estimatedTokenCount: Int
    let latencyMilliseconds: Int
    let mutationAuthority: Int
    let result: String
    let failure: String?

    static let idle = A10UltraM5ShadowCognitionSnapshot(
        evaluatedAt: .distantPast,
        runtimeID: "not-attached",
        outputDigest: "-",
        estimatedTokenCount: 0,
        latencyMilliseconds: 0,
        mutationAuthority: 0,
        result: "IDLE",
        failure: nil
    )
}

enum A10UltraM5Digest {
    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
