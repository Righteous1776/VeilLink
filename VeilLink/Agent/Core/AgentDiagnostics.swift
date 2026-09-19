import Foundation

struct AgentDiagnostics: Equatable, Sendable {
    var prepareCount = 0
    var generationCount = 0
    var cancellationCount = 0
    var memoryTrimCount = 0
    var unloadCount = 0
    var toolExecutionCount = 0
    var lastToolCommand: String?
    var lastGenerationMilliseconds: Int?
    var lastEstimatedTokenCount: Int?
    var lastFailure: String?

    func report(
        runtimeState: AgentRuntimeState,
        runtimeID: String,
        profile: AgentCapabilityProfile,
        sessionMessageCount: Int
    ) -> String {
        [
            "VeilLink Local Agent Diagnostics",
            "Runtime: \(runtimeID)",
            "Backend: \(LocalTextModelRuntimeFactory.backendName)",
            "Real local inference compiled: \(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled)",
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
            "Last tool: \(lastToolCommand ?? "-")",
            "Last duration ms: \(lastGenerationMilliseconds.map(String.init) ?? "-")",
            "Last estimated tokens: \(lastEstimatedTokenCount.map(String.init) ?? "-")",
            "Last failure: \(lastFailure ?? "-")",
            "Privacy: no peer message plaintext, attachments, pairing codes, identity keys, session keys, raw database paths, or system prompts are included."
        ].joined(separator: "\n")
    }
}
