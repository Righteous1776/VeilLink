import Combine
import Foundation

private final class WeakMaleCNSComputeConsumer {
    weak var value: MaleCNSComputeConsumer?
    init(_ value: MaleCNSComputeConsumer) { self.value = value }
}

@MainActor
final class VeilA9ComputeGovernor: ObservableObject {
    @Published private(set) var plan: VeilA9ComputePlan
    @Published private(set) var focus: AgentComputeFocus = .idle
    @Published private(set) var foregroundActive = true
    @Published private(set) var experimentalCoreEnabled = false

    let profile: AgentCapabilityProfile
    var onPlanChanged: ((VeilA9ComputePlan) -> Void)?
    var hasBoundMaleCNSConsumer: Bool { maleCNSConsumer != nil }
    private var decision: VeilA9Decision = .initial
    private let logicalProcessorCount: Int
    private weak var maleCNSConsumer: (any MaleCNSComputeConsumer)?
    private var maleCNSConsumers: [WeakMaleCNSComputeConsumer] = []

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
            logicalProcessorCount: max(1, logicalProcessorCount)
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

    func setExperimentalCoreEnabled(_ enabled: Bool) {
        guard experimentalCoreEnabled != enabled else { return }
        experimentalCoreEnabled = enabled
        recompute()
    }

    /// Attaches the current MaleCNS runtime to A9 scheduling. The consumer receives the current
    /// budget immediately and every later lattice/focus update. A weak reference keeps runtime
    /// lifecycle ownership outside the governor.
    func bindMaleCNSConsumer(_ consumer: (any MaleCNSComputeConsumer)?) {
        maleCNSConsumer = consumer
        consumer?.applyComputeBudget(plan.maleCNS)
    }

    /// Registers a MaleCNS runtime for live A9 budget updates. The governor keeps only a weak
    /// reference so loading/unloading a graph never depends on the UI or governor lifetime.
    func registerMaleCNSConsumer(_ consumer: MaleCNSComputeConsumer) {
        maleCNSConsumers.removeAll { $0.value == nil }
        guard !maleCNSConsumers.contains(where: { $0.value === consumer }) else {
            consumer.applyComputeBudget(plan.maleCNS)
            return
        }
        maleCNSConsumers.append(WeakMaleCNSComputeConsumer(consumer))
        consumer.applyComputeBudget(plan.maleCNS)
    }

    func trimMaleCNSConsumers() {
        maleCNSConsumers.removeAll { wrapper in
            guard let consumer = wrapper.value else { return true }
            consumer.trimComputeState()
            return false
        }
    }

    private func recompute() {
        plan = VeilA9ComputePlanner.plan(
            decision: decision,
            profile: profile,
            focus: focus,
            logicalProcessorCount: logicalProcessorCount,
            foregroundActive: foregroundActive,
            allowExperimentalCore: experimentalCoreEnabled
        )
        maleCNSConsumer?.applyComputeBudget(plan.maleCNS)
        onPlanChanged?(plan)
        maleCNSConsumers.removeAll { wrapper in
            guard let consumer = wrapper.value else { return true }
            consumer.applyComputeBudget(plan.maleCNS)
            return false
        }
    }

    func report() -> String {
        [
            "VeilLink A9 Compute Governor",
            "Mode: \(plan.mode.title)",
            "Focus: \(plan.focus.title)",
            "Foreground: \(foregroundActive ? "yes" : "no")",
            "Experimental Core authorized: \(experimentalCoreEnabled ? "yes" : "no")",
            "Lattice cell: \(plan.latticeIndex)/143",
            "Compute units: \(plan.totalComputeUnits)",
            "Transport reserve: \(plan.transportReserveUnits)",
            "MaleCNS units: \(plan.maleCNSUnits) · \(plan.maleCNS.tier.rawValue) · workers \(plan.maleCNS.workerCount) · steps \(plan.maleCNS.neuralStepBudget)",
            "MaleCNS runtime bound: \(hasBoundMaleCNSConsumer ? "yes" : "no")",
            "Language units: \(plan.languageUnits) · max tokens \(plan.language.maxNewTokens)",
            "Vision units: \(plan.visionUnits) · interval \(plan.vision.sampleIntervalMilliseconds) ms",
            "Game units: \(plan.gameUnits) · depth \(plan.game.searchDepth) · rollouts \(plan.game.rolloutCount)",
            "Training units: \(plan.trainingUnits) · enabled \(plan.training.enabled)",
            "Policy: A9 schedules existing compute; it does not bypass BLE, game legality, privacy, or iOS thermal limits."
        ].joined(separator: "\n")
    }
}
