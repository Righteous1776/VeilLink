import Foundation

struct LocalTextModelManifest: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let upstream: String
    let license: String
    let quantization: String
    let sha256: String
    let byteCount: Int
    let contextLimit: Int
    let recommendedProfile: String
    let minimumOS: String
}
