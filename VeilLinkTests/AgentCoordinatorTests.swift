import XCTest
@testable import VeilLink

final class AgentCoordinatorTests: XCTestCase {
    func testSessionTrimsWithoutPersistenceDependency() {
        var session = AgentSession(id: "local")
        for index in 0..<7 {
            session.append(AgentMessage(id: "m\(index)", role: .user, text: "\(index)"), limit: 4)
        }
        XCTAssertEqual(session.messages.map(\.id), ["m3", "m4", "m5", "m6"])
        XCTAssertEqual(session.recentMessages(limit: 2).map(\.id), ["m5", "m6"])
    }

    @MainActor
    func testLegacyMemoryPressureUnloadsRuntime() async {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let coordinator = AgentCoordinator(runtime: MockLocalTextModelRuntime(), capabilityProfile: profile)
        await coordinator.prepareForUse()
        XCTAssertEqual(coordinator.runtimeState, .ready)
        coordinator.handleMemoryPressure()
        XCTAssertEqual(coordinator.runtimeState, .unloaded)
        XCTAssertGreaterThanOrEqual(coordinator.diagnostics.memoryTrimCount, 1)
        XCTAssertGreaterThanOrEqual(coordinator.diagnostics.unloadCount, 1)
    }

    @MainActor
    func testDiagnosticsReportExcludesSecretCategories() {
        let coordinator = AgentCoordinator(
            runtime: MockLocalTextModelRuntime(),
            capabilityProfile: .profile(devicePerformanceLabel: "SE2-BALANCED")
        )
        let report = coordinator.diagnosticsReport()
        XCTAssertTrue(report.contains("Privacy:"))
        XCTAssertFalse(report.contains("pairingCode"))
        XCTAssertFalse(report.contains("sessionKey"))
        XCTAssertFalse(report.contains("privateKey"))
    }
}
