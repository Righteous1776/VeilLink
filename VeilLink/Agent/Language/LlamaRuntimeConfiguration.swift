import Foundation

struct LlamaRuntimeConfiguration: Equatable, Sendable {
    let contextTokens: Int
    let batchTokens: Int
    let threads: Int
    let gpuLayers: Int32
    let temperature: Float
    let topK: Int32
    let topP: Float
    let minP: Float

    static func resolved(profile: AgentCapabilityProfile) -> LlamaRuntimeConfiguration {
        let processorCount = max(1, ProcessInfo.processInfo.processorCount)
        switch profile.tier {
        case .legacyA10:
            return LlamaRuntimeConfiguration(
                contextTokens: 768,
                batchTokens: 64,
                threads: min(2, processorCount),
                gpuLayers: 0,
                temperature: 0.55,
                topK: 20,
                topP: 0.82,
                minP: 0.05
            )
        case .balanced:
            return LlamaRuntimeConfiguration(
                contextTokens: 1_536,
                batchTokens: 128,
                threads: min(4, processorCount),
                gpuLayers: -1,
                temperature: 0.60,
                topK: 24,
                topP: 0.86,
                minP: 0.05
            )
        case .high:
            return LlamaRuntimeConfiguration(
                contextTokens: 2_048,
                batchTokens: 256,
                threads: min(4, processorCount),
                gpuLayers: -1,
                temperature: 0.62,
                topK: 28,
                topP: 0.88,
                minP: 0.04
            )
        }
    }
}
