import XCTest
@testable import VeilLink

final class A9RuntimeConstraintTests: XCTestCase {
    func testHighProfileDefaultsToLiteUnlessExperimentalCoreIsExplicit() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")

        let stable = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .maleCNSSandbox,
            logicalProcessorCount: 6
        )
        XCTAssertEqual(stable.maleCNS.tier, .lite)

        let experimental = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .maleCNSSandbox,
            logicalProcessorCount: 6,
            allowExperimentalCore: true
        )
        XCTAssertEqual(experimental.maleCNS.tier, .core)
    }

    func testBackgroundSuspendsOptionalAgentCompute() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let plan = VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .languageChat,
            logicalProcessorCount: 6,
            foregroundActive: false
        )

        XCTAssertEqual(plan.maleCNS.tier, .suspended)
        XCTAssertEqual(plan.optionalComputeUnits, 0)
        XCTAssertFalse(plan.training.enabled)
        XCTAssertFalse(plan.vision.enabled)
        XCTAssertFalse(plan.language.keepWarm)
        XCTAssertEqual(plan.transportReserveUnits, plan.totalComputeUnits)
    }

    func testThermalAndLowPowerClampImmediately() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")

        let lowPower = VeilA9Decision(
            light: .yellow,
            level: .l0Observe,
            reasonCode: "TEST",
            healthScore: 95,
            riskPoints: 1,
            persistenceRuns: 0,
            issues: [
                VeilA9Issue(
                    code: "LOW_POWER_MODE",
                    severity: .p3,
                    source: "system",
                    detail: "test"
                )
            ],
            latticeIndex: 0
        )
        XCTAssertEqual(
            VeilA9ComputePlanner.plan(
                decision: lowPower,
                profile: profile,
                focus: .languageChat,
                logicalProcessorCount: 6
            ).mode,
            .constrained
        )

        let serious = VeilA9Decision(
            light: .yellow,
            level: .l1Advisory,
            reasonCode: "TEST",
            healthScore: 80,
            riskPoints: 4,
            persistenceRuns: 0,
            issues: [
                VeilA9Issue(
                    code: "THERMAL_SERIOUS",
                    severity: .p2,
                    source: "system",
                    detail: "test"
                )
            ],
            latticeIndex: 0
        )
        XCTAssertEqual(
            VeilA9ComputePlanner.plan(
                decision: serious,
                profile: profile,
                focus: .gameDecision,
                logicalProcessorCount: 6
            ).mode,
            .preserve
        )

        let critical = VeilA9Decision(
            light: .yellow,
            level: .l2Review,
            reasonCode: "TEST",
            healthScore: 70,
            riskPoints: 12,
            persistenceRuns: 0,
            issues: [
                VeilA9Issue(
                    code: "THERMAL_CRITICAL",
                    severity: .p1,
                    source: "system",
                    detail: "test"
                )
            ],
            latticeIndex: 0
        )
        XCTAssertEqual(
            VeilA9ComputePlanner.plan(
                decision: critical,
                profile: profile,
                focus: .gameDecision,
                logicalProcessorCount: 6
            ).mode,
            .emergency
        )
    }

    func testStreamingFlushIntervalsFavorLegacyEfficiency() {
        XCTAssertEqual(
            AgentCoordinator.streamingFlushIntervalMilliseconds(for: .legacyA10),
            50
        )
        XCTAssertEqual(
            AgentCoordinator.streamingFlushIntervalMilliseconds(for: .balanced),
            35
        )
        XCTAssertEqual(
            AgentCoordinator.streamingFlushIntervalMilliseconds(for: .high),
            25
        )
    }

    @MainActor
    func testCoreGovernorClampsExperimentalRuntimeOff() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let governor = VeilA9ComputeGovernor(profile: profile, logicalProcessorCount: 6)
        governor.setExperimentalCoreEnabled(true)
        XCTAssertFalse(governor.experimentalCoreEnabled)
    }
}
