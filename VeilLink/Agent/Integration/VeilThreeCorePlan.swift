import Foundation

enum VeilThreeCorePhase: String, Codable, Sendable {
    case insertionReady = "THREE_CORE_INSERTION_READY"
    case a10ComputeAttached = "A10_COMPUTE_ATTACHED"
    case a10ComputeActive = "A10_COMPUTE_ACTIVE"
    case fallback = "A10_COMPUTE_FALLBACK"
}

enum VeilThreeCoreRole: String, Codable, Sendable {
    case governance = "GOVERNANCE"
    case compute = "COMPUTE"
    case orchestration = "ORCHESTRATION"
}

struct VeilThreeCoreSnapshot: Equatable, Sendable {
    let phase: VeilThreeCorePhase
    let a9Role: VeilThreeCoreRole
    let a10Role: VeilThreeCoreRole
    let lingCoreRole: VeilThreeCoreRole
    let a10RuntimeID: String?
    let a10RuntimeState: String
    let languageBackend: String
    let a9BudgetMode: String
    let mutationAuthorityOwner: String
    let legacyGovernanceShadow: String
    let fallbackReason: String?

    static func initial(languageBackend: String, budgetMode: String) -> VeilThreeCoreSnapshot {
        VeilThreeCoreSnapshot(
            phase: .insertionReady,
            a9Role: .governance,
            a10Role: .compute,
            lingCoreRole: .orchestration,
            a10RuntimeID: nil,
            a10RuntimeState: A10UltraComputeState.detached.rawValue,
            languageBackend: languageBackend,
            a9BudgetMode: budgetMode,
            mutationAuthorityOwner: "VEILLINK_HOST_ACTION_LAYER",
            legacyGovernanceShadow: "RETAINED_COMPATIBILITY_HARNESS",
            fallbackReason: nil
        )
    }

    var report: String {
        [
            "VeilLink Three-Core Runtime",
            "Phase: \(phase.rawValue)",
            "A9: \(a9Role.rawValue) · safety/health/budget governance",
            "A10 Ultra Ω: \(a10Role.rawValue) · runtime=\(a10RuntimeID ?? "EMPTY_READY") · state=\(a10RuntimeState)",
            "LingCore: \(lingCoreRole.rawValue) · backend=\(languageBackend)",
            "A9 budget mode: \(a9BudgetMode)",
            "Mutation authority: \(mutationAuthorityOwner)",
            "Legacy OMEGA governance shadow: \(legacyGovernanceShadow)",
            "Fallback reason: \(fallbackReason ?? "none")",
            "Policy: A10 computes; LingCore orchestrates; A9 governs resources/safety; host Action Layer alone mutates app state."
        ].joined(separator: "\n")
    }
}
