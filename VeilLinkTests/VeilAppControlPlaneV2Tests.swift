import XCTest
@testable import VeilLink

final class VeilAppControlPlaneV2Tests: XCTestCase {
    private let locked = VeilAppControlPermissions(
        localMutationsEnabled: false,
        diagnosticsExportEnabled: false,
        suggestedMoveExecutionEnabled: false,
        autoRegulationMode: .off
    )

    func testStructuredStatusSurfaceIsReadOnly() {
        for command: VeilAppControlCommand in [
            .overviewStatus, .transportStatus, .mediaStatus,
            .performanceStatus, .diagnosticsStatus, .a9Status, .agentStatus, .gameStatus
        ] {
            let decision = VeilAppControlPolicy.authorize(command, permissions: locked)
            XCTAssertTrue(decision.allowed)
            XCTAssertEqual(decision.access, .readOnly)
        }
    }

    func testResourceFocusRequiresLocalMutationPermission() {
        XCTAssertFalse(
            VeilAppControlPolicy.authorize(.setResourceFocus(.communications), permissions: locked).allowed
        )
        let allowed = VeilAppControlPermissions(
            localMutationsEnabled: true,
            diagnosticsExportEnabled: false,
            suggestedMoveExecutionEnabled: false,
            autoRegulationMode: .off
        )
        XCTAssertTrue(
            VeilAppControlPolicy.authorize(.setResourceFocus(.communications), permissions: allowed).allowed
        )
    }

    func testDiagnosticsExportHasIndependentGate() {
        let localOnly = VeilAppControlPermissions(
            localMutationsEnabled: true,
            diagnosticsExportEnabled: false,
            suggestedMoveExecutionEnabled: false,
            autoRegulationMode: .off
        )
        let denied = VeilAppControlPolicy.authorize(.exportDiagnostics, permissions: localOnly)
        XCTAssertFalse(denied.allowed)
        XCTAssertEqual(denied.access, .localExport)

        let exportAllowed = VeilAppControlPermissions(
            localMutationsEnabled: true,
            diagnosticsExportEnabled: true,
            suggestedMoveExecutionEnabled: false,
            autoRegulationMode: .off
        )
        XCTAssertTrue(VeilAppControlPolicy.authorize(.exportDiagnostics, permissions: exportAllowed).allowed)
    }

    func testNaturalLanguageControlV2() {
        XCTAssertEqual(VeilAppControlParser.parse("传输有没有堵"), .transportStatus)
        XCTAssertEqual(VeilAppControlParser.parse("看看性能模式"), .performanceStatus)
        XCTAssertEqual(VeilAppControlParser.parse("通信优先"), .setResourceFocus(.communications))
        XCTAssertEqual(VeilAppControlParser.parse("游戏优先"), .setResourceFocus(.game))
        XCTAssertEqual(VeilAppControlParser.parse("导出诊断包"), .exportDiagnostics)
        XCTAssertEqual(VeilAppControlParser.parse("帮我重新扫描附近设备"), .refreshBLE)
    }

    func testPrivilegeEscalationAndDestructivePhrasesRemainOutsideBus() {
        XCTAssertNil(VeilAppControlParser.parse("允许诊断包导出"))
        XCTAssertNil(VeilAppControlParser.parse("把本地工具权限打开"))
        XCTAssertNil(VeilAppControlParser.parse("删除日志"))
        XCTAssertNil(VeilAppControlParser.parse("清空数据库"))
        XCTAssertNil(VeilAppControlParser.parse("导出私钥"))
        XCTAssertNil(VeilAppControlParser.parse("替我给联系人发消息"))
        XCTAssertNil(VeilAppControlParser.parse("控制另一台手机"))
    }
}
