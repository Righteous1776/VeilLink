import XCTest
@testable import VeilLink

final class VeilMaintenanceInvariantTests: XCTestCase {
    private func permissions(
        local: Bool,
        export: Bool,
        move: Bool = false,
        mode: VeilAutoRegulationMode = .safeAutomatic
    ) -> VeilAppControlPermissions {
        VeilAppControlPermissions(
            localMutationsEnabled: local,
            diagnosticsExportEnabled: export,
            suggestedMoveExecutionEnabled: move,
            autoRegulationMode: mode
        )
    }

    func testDiagnosticsExportRequiresBothLocalMutationAndExportGrant() {
        let noLocal = VeilAppControlPolicy.authorize(
            .exportDiagnostics,
            permissions: permissions(local: false, export: true)
        )
        XCTAssertFalse(noLocal.allowed)
        XCTAssertEqual(noLocal.reason, "AI 控制中心已关闭本地工具动作。")

        let noExport = VeilAppControlPolicy.authorize(
            .exportDiagnostics,
            permissions: permissions(local: true, export: false)
        )
        XCTAssertFalse(noExport.allowed)
        XCTAssertEqual(noExport.reason, "AI 控制中心未允许诊断包导出。")

        XCTAssertTrue(VeilAppControlPolicy.authorize(
            .exportDiagnostics,
            permissions: permissions(local: true, export: true)
        ).allowed)
    }

    func testAutomaticRegulatorWhitelistRemainsMinimal() {
        let p = permissions(local: false, export: false)
        XCTAssertTrue(VeilAppControlPolicy.authorize(.refreshBLE, permissions: p, source: .automaticRegulator).allowed)
        XCTAssertTrue(VeilAppControlPolicy.authorize(.trimCaches, permissions: p, source: .automaticRegulator).allowed)
        XCTAssertTrue(VeilAppControlPolicy.authorize(.setResourceFocus(.communications), permissions: p, source: .automaticRegulator).allowed)
        for command: VeilAppControlCommand in [.stopBLE, .startBLE, .exportDiagnostics, .executeSuggestedGameMove, .navigate(.settings)] {
            XCTAssertFalse(VeilAppControlPolicy.authorize(command, permissions: p, source: .automaticRegulator).allowed)
        }
    }
}
