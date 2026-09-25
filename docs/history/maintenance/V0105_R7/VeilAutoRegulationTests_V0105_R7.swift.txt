import XCTest
@testable import VeilLink

final class VeilAutoRegulationTests: XCTestCase {
    private func snapshot(
        mode: VeilAutoRegulationMode = .safeAutomatic,
        thermal: VeilAutoThermalLevel = .nominal,
        lowPower: Bool = false,
        health: Int = 95,
        pending: Int = 0,
        control: Int = 0,
        stall: Int = 0,
        recovering: Int = 0,
        focus: VeilAppResourceFocus = .automatic,
        destination: VeilAppDestination = .chats,
        generating: Bool = false,
        gameActive: Bool = false,
        hold: Bool = false,
        sinceMutation: TimeInterval? = 120,
        sinceMaintenance: TimeInterval? = 120,
        sinceRepair: TimeInterval? = 120
    ) -> VeilAutoRegulationSnapshot {
        VeilAutoRegulationSnapshot(
            mode: mode, thermal: thermal, lowPowerMode: lowPower, a9HealthScore: health,
            pendingBytes: pending, controlPendingPackets: control, maximumStallMilliseconds: stall,
            recoveringPeerCount: recovering, connectedPeerCount: 1, currentFocus: focus,
            visibleDestination: destination, agentGenerating: generating, gameActive: gameActive,
            manualFocusHoldActive: hold, secondsSinceLastMutation: sinceMutation,
            secondsSinceLastMaintenance: sinceMaintenance, secondsSinceLastBLERepair: sinceRepair
        )
    }

    func testCriticalThermalOnlyUsesReversibleProtectionActions() {
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot(thermal: .critical, focus: .game))
        XCTAssertEqual(plan.severity, .protection)
        XCTAssertTrue(plan.actions.contains(.setFocus(.automatic)))
        XCTAssertTrue(plan.actions.contains(.trimCaches))
        XCTAssertFalse(plan.actions.contains(.refreshBLE))
    }

    func testSevereTransportGetsCommunicationsFocusAndRepair() {
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot(pending: 500 * 1024, stall: 4000, recovering: 2))
        XCTAssertEqual(plan.severity, .pressure)
        XCTAssertTrue(plan.actions.contains(.setFocus(.communications)))
        XCTAssertTrue(plan.actions.contains(.refreshBLE))
    }

    func testManualHoldPreventsNormalFocusOverride() {
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot(
            focus: .game, destination: .agent, generating: true, hold: true
        ))
        XCTAssertTrue(plan.actions.isEmpty)
    }

    func testManualHoldStillAllowsBadBLERepair() {
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot(
            stall: 4000, recovering: 2, focus: .game, hold: true
        ))
        XCTAssertEqual(plan.actions, [.refreshBLE])
    }

    func testGameAndAgentForegroundHintsAreUsedWhenHealthy() {
        XCTAssertEqual(
            VeilAutoRegulationPolicy.evaluate(snapshot(destination: .games, gameActive: true)).actions,
            [.setFocus(.game)]
        )
        XCTAssertEqual(
            VeilAutoRegulationPolicy.evaluate(snapshot(destination: .agent, generating: true)).actions,
            [.setFocus(.agent)]
        )
    }

    func testMutationCooldownSuppressesOscillation() {
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot(
            pending: 500 * 1024, sinceMutation: 3
        ))
        XCTAssertTrue(plan.actions.isEmpty)
    }

    func testDisabledModeNeverActs() {
        XCTAssertTrue(VeilAutoRegulationPolicy.evaluate(snapshot(mode: .off, thermal: .critical)).actions.isEmpty)
    }
}
