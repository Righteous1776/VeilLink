import Foundation

struct AgentDiagnostics: Equatable, Sendable {
    var prepareCount = 0
    var generationCount = 0
    var cancellationCount = 0
    var memoryTrimCount = 0
    var unloadCount = 0
    var toolExecutionCount = 0
    var a10AttachCount = 0
    var a10FallbackCount = 0
    var lastA10FallbackReason: String?
    var lastToolCommand: String?
    var lastGenerationMilliseconds: Int?
    var lastEstimatedTokenCount: Int?
    var lastFailure: String?

    func report(
        runtimeState: AgentRuntimeState,
        runtimeID: String,
        backendName: String,
        realLocalInferenceActive: Bool,
        profile: AgentCapabilityProfile,
        sessionMessageCount: Int
    ) -> String {
        [
            "VeilLink Local Agent Diagnostics",
            "Runtime: \(runtimeID)",
            "Backend: \(backendName)",
            "Real local inference active: \(realLocalInferenceActive)",
            "State: \(runtimeState.rawValue)",
            "Profile: \(profile.id)",
            "Tier: \(profile.tier.rawValue)",
            "Session messages: \(sessionMessageCount)",
            "Prepare count: \(prepareCount)",
            "Generation count: \(generationCount)",
            "Cancellation count: \(cancellationCount)",
            "Memory trims: \(memoryTrimCount)",
            "Unloads: \(unloadCount)",
            "Tool executions: \(toolExecutionCount)",
            "A10 Ultra Ω attaches: \(a10AttachCount)",
            "A10 Ultra Ω fallbacks: \(a10FallbackCount)",
            "Last A10 fallback: \(lastA10FallbackReason ?? "-")",
            "Last tool: \(lastToolCommand ?? "-")",
            "Last duration ms: \(lastGenerationMilliseconds.map(String.init) ?? "-")",
            "Last estimated tokens: \(lastEstimatedTokenCount.map(String.init) ?? "-")",
            "Last failure: \(lastFailure ?? "-")",
            "Privacy: no peer message plaintext, attachments, pairing codes, identity keys, session keys, raw database paths, or system prompts are included."
        ].joined(separator: "\n")
    }
}
