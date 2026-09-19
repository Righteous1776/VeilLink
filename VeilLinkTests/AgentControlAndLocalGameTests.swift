import XCTest
@testable import VeilLink

@MainActor
final class AgentControlAndLocalGameTests: XCTestCase {
    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "studio.zeo.VeilLinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    func testExperimentalCoreDoesNotSurviveColdStart() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(
            AgentGameDecisionMode.experimentalCore.rawValue,
            forKey: "agent.controls.gameDecisionMode"
        )

        let settings = AgentControlCenterSettings(defaults: defaults)

        XCTAssertEqual(settings.gameDecisionMode, .automaticStable)
        XCTAssertEqual(
            defaults.string(forKey: "agent.controls.gameDecisionMode"),
            AgentGameDecisionMode.automaticStable.rawValue
        )
    }

    func testSuggestedMoveExecutionIsOffByDefault() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AgentControlCenterSettings(defaults: defaults)

        XCTAssertFalse(settings.allowSuggestedGameMoveExecution)
        XCTAssertEqual(settings.gameDecisionMode, .automaticStable)
    }

    func testLocalGomokuFallsBackToBaselineAndCompletesAITurn() async throws {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let controls = AgentControlCenterSettings(defaults: defaults)
        controls.gameDecisionMode = .baselineOnly

        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let governor = VeilA9ComputeGovernor(profile: profile, logicalProcessorCount: 2)
        let maleCNS = MaleCNSGraphManager(profile: profile, governor: governor)
        let controller = LocalAIGameController(
            game: .gomoku,
            maleCNS: maleCNS,
            controls: controls
        )

        XCTAssertTrue(controller.canHumanAct)
        controller.humanGomokuMove(112)

        XCTAssertEqual(controller.gomoku.value(at: 112), 1)
        XCTAssertTrue(controller.isAIThinking)

        let deadline = Date().addingTimeInterval(2.0)
        while controller.isAIThinking && Date() < deadline {
            try await Task.sleep(nanoseconds: 40_000_000)
        }

        XCTAssertFalse(controller.isAIThinking)
        XCTAssertEqual(controller.gomoku.currentPlayer, .host)
        XCTAssertEqual(controller.lastDecisionMode, "基础策略")

        let aiStoneCount = (0..<(GomokuState.size * GomokuState.size))
            .filter { controller.gomoku.value(at: $0) == 2 }
            .count
        XCTAssertEqual(aiStoneCount, 1)
    }

    func testRestartCancelsPendingAIAndPreventsGhostMove() async throws {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let controls = AgentControlCenterSettings(defaults: defaults)
        controls.gameDecisionMode = .baselineOnly

        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let governor = VeilA9ComputeGovernor(profile: profile, logicalProcessorCount: 2)
        let maleCNS = MaleCNSGraphManager(profile: profile, governor: governor)
        let controller = LocalAIGameController(
            game: .gomoku,
            maleCNS: maleCNS,
            controls: controls
        )

        let oldSessionID = controller.sessionID
        controller.humanGomokuMove(112)
        XCTAssertTrue(controller.isAIThinking)

        controller.restart()
        XCTAssertNotEqual(controller.sessionID, oldSessionID)
        XCTAssertFalse(controller.isAIThinking)
        XCTAssertEqual(controller.gomoku.currentPlayer, .host)

        try await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertFalse(controller.isAIThinking)
        let occupied = (0..<(GomokuState.size * GomokuState.size))
            .filter { controller.gomoku.value(at: $0) != 0 }
        XCTAssertTrue(occupied.isEmpty)
        XCTAssertEqual(controller.outcome, .playing)
    }
}
