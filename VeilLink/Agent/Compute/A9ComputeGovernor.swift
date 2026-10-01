import Combine
import Foundation

/// Core compute governor. R4 intentionally contains no runtime binding to MaleCNS.
/// The historical neural budget fields remain in VeilA9ComputePlan for backward-compatible
/// diagnostics and for the separately generated Experimental AI project, but Core never
/// allocates a runtime consumer from this class.
@MainActor
final class VeilA9ComputeGovernor: ObservableObject {
    @Published private(set) var plan: VeilA9ComputePlan
    @Published private(set) var focus: AgentComputeFocus = .idle
    @Published private(set) var foregroundActive = true
    @Published private(set) var experimentalCoreEnabled = false
    @Published private(set) var planFrozen = false

    let profile: AgentCapabilityProfile
    var onPlanChanged: ((VeilA9ComputePlan) -> Void)?

    private var decision: VeilA9Decision = .initial
    private let logicalProcessorCount: Int

    init(
        profile: AgentCapabilityProfile = .current,
        logicalProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount
    ) {
        self.profile = profile
        self.logicalProcessorCount = max(1, logicalProcessorCount)
        plan = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .idle,
            logicalProcessorCount: max(1, logicalProcessorCount),
            allowExperimentalCore: false
        )
    }

    func update(decision: VeilA9Decision) {
        self.decision = decision
        recompute()
    }

    func setFocus(_ focus: AgentComputeFocus) {
        guard self.focus != focus else { return }
        self.focus = focus
        recompute()
    }

    func setForegroundActive(_ active: Bool) {
        guard foregroundActive != active else { return }
        foregroundActive = active
        recompute()
    }

    /// Kept as a migration-safe API. Core always clamps this to false.
    func setExperimentalCoreEnabled(_ enabled: Bool) {
        guard experimentalCoreEnabled != false || enabled else { return }
        experimentalCoreEnabled = false
        recompute()
    }

    /// I8 LAB isolation: keep the last already-committed A9 plan byte-for-byte stable while
    /// A10 Ultra Ω is measured alone. Unfreezing immediately recomputes from the last A9 decision.
    func setPlanFrozen(_ frozen: Bool, recomputeOnUnfreeze: Bool = true) {
        guard planFrozen != frozen else { return }
        planFrozen = frozen
        if !frozen, recomputeOnUnfreeze { recompute() }
    }

    private func recompute() {
        guard !planFrozen else { return }
        plan = VeilA9ComputePlanner.plan(
            decision: decision,
            profile: profile,
            focus: focus,
            logicalProcessorCount: logicalProcessorCount,
            foregroundActive: foregroundActive,
            allowExperimentalCore: false
        )
        onPlanChanged?(plan)
    }

    func report() -> String {
        [
            "VeilLink A9 Compute Governor",
            "Mode: \(plan.mode.title)",
            "Focus: \(plan.focus.title)",
            "Foreground: \(foregroundActive ? "yes" : "no")",
            "Experimental neural runtime: excluded from Core target",
            "Plan frozen: \(planFrozen ? "yes" : "no")",
            "Lattice cell: \(plan.latticeIndex)/143",
            "Compute units: \(plan.totalComputeUnits)",
            "Transport reserve: \(plan.transportReserveUnits)",
            "Language units: \(plan.languageUnits) · max tokens \(plan.language.maxNewTokens)",
            "Vision units: \(plan.visionUnits) · interval \(plan.vision.sampleIntervalMilliseconds) ms",
            "Game units: \(plan.gameUnits) · depth \(plan.game.searchDepth) · rollouts \(plan.game.rolloutCount)",
            "Training units: \(plan.trainingUnits) · enabled \(plan.training.enabled)",
            "Policy: A9 schedules existing compute; it does not bypass BLE, game legality, privacy, or iOS thermal limits."
        ].joined(separator: "\n")
    }
}
