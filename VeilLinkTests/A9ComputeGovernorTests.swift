import XCTest
@testable import VeilLink

final class A9ComputeGovernorTests: XCTestCase {
    func testGreenHighProfileDefaultsToLiteUntilCoreIsExplicitlyAuthorized() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let stable = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .maleCNSSandbox,
            logicalProcessorCount: 6
        )
        XCTAssertEqual(stable.mode, .boost)
        XCTAssertEqual(stable.maleCNS.tier, .lite)
        XCTAssertGreaterThan(stable.maleCNSUnits, stable.languageUnits)

        let experimental = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .maleCNSSandbox,
            logicalProcessorCount: 6,
            allowExperimentalCore: true
        )
        XCTAssertEqual(experimental.maleCNS.tier, .core)
        XCTAssertGreaterThanOrEqual(experimental.maleCNS.workerCount, 2)
        XCTAssertGreaterThan(experimental.maleCNS.neuralStepBudget, 100)
    }

    func testLegacyA10KeepsMaleCNSLiteAndConservative() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let plan = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .maleCNSSandbox,
            logicalProcessorCount: 4
        )
        XCTAssertEqual(plan.maleCNS.tier, .lite)
        XCTAssertLessThanOrEqual(plan.maleCNS.workerCount, 1)
        XCTAssertLessThanOrEqual(plan.language.maxNewTokens, profile.maxNewTokens)
    }

    func testControlBacklogReservesMoreComputeForTransport() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let normal = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .videoChat,
            logicalProcessorCount: 6
        )
        let issue = VeilA9Issue(
            code: "CONTROL_BACKLOG_HIGH",
            severity: .p1,
            source: "ble",
            detail: "test"
        )
        let pressured = VeilA9Decision(
            light: .yellow,
            level: .l2Review,
            reasonCode: "YELLOW_PERSISTENT_OR_P1",
            healthScore: 80,
            riskPoints: 12,
            persistenceRuns: 3,
            issues: [issue],
            latticeIndex: 42
        )
        let constrained = VeilA9ComputePlanner.plan(
            decision: pressured,
            profile: profile,
            focus: .videoChat,
            logicalProcessorCount: 6
        )
        XCTAssertGreaterThan(constrained.transportReserveUnits, normal.transportReserveUnits)
        XCTAssertLessThan(constrained.visionUnits, normal.visionUnits)
    }

    func testEmergencyNeverEnablesBackgroundTraining() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let decision = VeilA9Decision(
            light: .red,
            level: .l5Emergency,
            reasonCode: "P0_HARD_BREAK",
            healthScore: 40,
            riskPoints: 40,
            persistenceRuns: 1,
            issues: [],
            latticeIndex: 143
        )
        let plan = VeilA9ComputePlanner.plan(
            decision: decision,
            profile: profile,
            focus: .idle,
            logicalProcessorCount: 6
        )
        XCTAssertEqual(plan.mode, .emergency)
        XCTAssertFalse(plan.training.enabled)
        XCTAssertGreaterThanOrEqual(plan.language.maxNewTokens, 32)
    }

    func testAll144LatticeCellsProduceBoundedNonNegativePlans() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "SE2-BALANCED")
        for index in VeilA9Lattice.cells.indices {
            let cell = VeilA9Lattice.cells[index]
            let decision = VeilA9Decision(
                light: .yellow,
                level: cell.level,
                reasonCode: cell.reasonCode,
                healthScore: 70,
                riskPoints: 8,
                persistenceRuns: 1,
                issues: [],
                latticeIndex: index
            )
            let plan = VeilA9ComputePlanner.plan(
                decision: decision,
                profile: profile,
                focus: .gameDecision,
                logicalProcessorCount: 4
            )
            XCTAssertGreaterThanOrEqual(plan.totalComputeUnits, 0)
            XCTAssertGreaterThanOrEqual(plan.transportReserveUnits, 0)
            XCTAssertLessThanOrEqual(plan.transportReserveUnits, plan.totalComputeUnits)
            XCTAssertGreaterThanOrEqual(plan.optionalComputeUnits, 0)
            XCTAssertLessThanOrEqual(plan.optionalComputeUnits + plan.transportReserveUnits, plan.totalComputeUnits)
        }
    }
    @MainActor
    func testGovernorPushesLiveBudgetIntoMaleCNSConsumer() {
        final class Probe: MaleCNSComputeConsumer {
            var budgets: [MaleCNSComputeBudget] = []
            var trimCount = 0
            func applyComputeBudget(_ budget: MaleCNSComputeBudget) { budgets.append(budget) }
            func trimComputeState() { trimCount += 1 }
        }

        let governor = VeilA9ComputeGovernor(
            profile: AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH"),
            logicalProcessorCount: 6
        )
        let probe = Probe()
        governor.registerMaleCNSConsumer(probe)
        XCTAssertEqual(probe.budgets.last, governor.plan.maleCNS)

        governor.setFocus(.maleCNSSandbox)
        XCTAssertEqual(probe.budgets.last, governor.plan.maleCNS)
        XCTAssertGreaterThanOrEqual(probe.budgets.count, 2)

        governor.trimMaleCNSConsumers()
        XCTAssertEqual(probe.trimCount, 1)
    }

    @MainActor
    func testGovernorPushesBudgetsIntoBoundMaleCNSRuntime() {
        final class Consumer: MaleCNSComputeConsumer {
            var received: [MaleCNSComputeBudget] = []
            func applyComputeBudget(_ budget: MaleCNSComputeBudget) { received.append(budget) }
            func trimComputeState() {}
        }

        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let governor = VeilA9ComputeGovernor(profile: profile, logicalProcessorCount: 6)
        let consumer = Consumer()
        governor.bindMaleCNSConsumer(consumer)
        XCTAssertEqual(consumer.received.last, governor.plan.maleCNS)

        governor.setFocus(.maleCNSSandbox)
        XCTAssertEqual(consumer.received.last, governor.plan.maleCNS)
        XCTAssertEqual(consumer.received.last?.tier, .lite)

        governor.setExperimentalCoreEnabled(true)
        XCTAssertEqual(consumer.received.last?.tier, .core)

        governor.update(decision: VeilA9Decision(
            light: .red, level: .l5Emergency, reasonCode: "P0_HARD_BREAK",
            healthScore: 30, riskPoints: 40, persistenceRuns: 1, issues: [], latticeIndex: 143
        ))
        XCTAssertEqual(consumer.received.last?.tier, .suspended)
    }

}
