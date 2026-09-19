import Foundation

struct LocalModelDescriptor: Equatable, Sendable {
    let id: String
    let displayName: String
    let resourceName: String
    let fileExtension: String
    let upstream: String
    let license: String
    let quantization: String
    let sha256: String
    let expectedMinimumBytes: Int64
    let contextLimit: Int
    let minimumOS: String

    var manifest: LocalTextModelManifest {
        LocalTextModelManifest(
            id: id,
            displayName: displayName,
            upstream: upstream,
            license: license,
            quantization: quantization,
            sha256: sha256,
            byteCount: Int(expectedMinimumBytes),
            contextLimit: contextLimit,
            recommendedProfile: "legacyA10|balanced|high",
            minimumOS: minimumOS
        )
    }
}

enum LocalModelCatalog {
    static let primary = LocalModelDescriptor(
        id: "qwen3-0.6b-q4_0.gguf.v1",
        displayName: "Qwen3-0.6B Q4_0",
        resourceName: "Qwen3-0.6B-Q4_0",
        fileExtension: "gguf",
        upstream: "ggml-org/Qwen3-0.6B-GGUF",
        license: "Apache-2.0",
        quantization: "Q4_0",
        sha256: "da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4",
        expectedMinimumBytes: 400 * 1_024 * 1_024,
        contextLimit: 32_768,
        minimumOS: "15.0"
    )

    static let qwenModelRevision = "a41486f827d17edd055fe6b3b0ba3f8d427c0519"
    static let llamaCPPCommit = "b29c606e28a01b1bc8c1351026a0fa6e616bf6c4"
    static let llamaCPPRelease = "v0.4.1"
}
