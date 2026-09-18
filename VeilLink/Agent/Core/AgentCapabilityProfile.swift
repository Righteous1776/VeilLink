import Foundation

enum AgentComputeTier: String, Codable, Sendable {
    case legacyA10
    case balanced
    case high
}

struct AgentCapabilityProfile: Equatable, Sendable {
    let id: String
    let tier: AgentComputeTier
    let displayName: String
    let recentMessageLimit: Int
    let transcriptLimit: Int
    let maxNewTokens: Int
    let unloadOnBackground: Bool
    let unloadOnMemoryPressure: Bool

    static func profile(devicePerformanceLabel label: String) -> AgentCapabilityProfile {
        switch label {
        case "SE1-LOW", "LEGACY-COMPACT":
            return AgentCapabilityProfile(
                id: "agent.legacy-a10.v1",
                tier: .legacyA10,
                displayName: "Legacy · A10",
                recentMessageLimit: 8,
                transcriptLimit: 24,
                maxNewTokens: 96,
                unloadOnBackground: true,
                unloadOnMemoryPressure: true
            )
        case "13PRO-HIGH":
            return AgentCapabilityProfile(
                id: "agent.high.v1",
                tier: .high,
                displayName: "High · Local",
                recentMessageLimit: 24,
                transcriptLimit: 72,
                maxNewTokens: 256,
                unloadOnBackground: false,
                unloadOnMemoryPressure: false
            )
        default:
            return AgentCapabilityProfile(
                id: "agent.balanced.v1",
                tier: .balanced,
                displayName: "Balanced · Local",
                recentMessageLimit: 16,
                transcriptLimit: 48,
                maxNewTokens: 160,
                unloadOnBackground: false,
                unloadOnMemoryPressure: false
            )
        }
    }

    static var current: AgentCapabilityProfile {
        profile(devicePerformanceLabel: VeilDevicePerformance.current.label)
    }
}
