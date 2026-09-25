import XCTest
@testable import VeilLink

final class VeilAppControlPlaneV3Tests: XCTestCase {
    private let locked = VeilAppControlPermissions(
        localMutationsEnabled: false,
        diagnosticsExportEnabled: false,
        suggestedMoveExecutionEnabled: false,
        autoRegulationMode: .safeAutomatic
    )

    func testAutoRegulationStatusIsReadOnly() {
        let d = VeilAppControlPolicy.authorize(.autoRegulationStatus, permissions: locked)
        XCTAssertTrue(d.allowed)
        XCTAssertEqual(d.access, .readOnly)
    }

    func testAutomaticRegulatorCanOnlyUseSafeWhitelist() {
        XCTAssertTrue(VeilAppControlPolicy.authorize(
            .setResourceFocus(.communications), permissions: locked, source: .automaticRegulator
        ).allowed)
        XCTAssertTrue(VeilAppControlPolicy.authorize(
            .trimCaches, permissions: locked, source: .automaticRegulator
        ).allowed)
        XCTAssertTrue(VeilAppControlPolicy.authorize(
            .refreshBLE, permissions: locked, source: .automaticRegulator
        ).allowed)

        for forbidden: VeilAppControlCommand in [
            .stopBLE, .startBLE, .databaseIntegrity, .exportDiagnostics,
            .executeSuggestedGameMove, .navigate(.settings), .activateAgentRuntime,
            .setVisualContext(true), .setAutoSaveReceivedImages(true)
        ] {
            XCTAssertFalse(VeilAppControlPolicy.authorize(
                forbidden, permissions: locked, source: .automaticRegulator
            ).allowed)
        }
    }

    func testAutomaticSourceRequiresSafeAutomaticMode() {
        let advisory = VeilAppControlPermissions(
            localMutationsEnabled: true,
            diagnosticsExportEnabled: true,
            suggestedMoveExecutionEnabled: true,
            autoRegulationMode: .advisory
        )
        XCTAssertFalse(VeilAppControlPolicy.authorize(
            .trimCaches, permissions: advisory, source: .automaticRegulator
        ).allowed)
    }

    func testAutoTuneNaturalLanguageSurface() {
        XCTAssertEqual(VeilAppControlParser.parse("自动调控状态"), .autoRegulationStatus)
        XCTAssertEqual(VeilAppControlParser.parse("开启安全自动调控"), .setAutoRegulationMode(.safeAutomatic))
        XCTAssertEqual(VeilAppControlParser.parse("自动调控只建议"), .setAutoRegulationMode(.advisory))
        XCTAssertEqual(VeilAppControlParser.parse("关闭自动调控"), .setAutoRegulationMode(.off))
        XCTAssertEqual(VeilAppControlParser.parse("现在自动诊断"), .runAutoRegulationOnce)
    }

    func testPrivilegeAndDestructiveCommandsRemainAbsent() {
        XCTAssertNil(VeilAppControlParser.parse("自动打开所有权限"))
        XCTAssertNil(VeilAppControlParser.parse("自动导出诊断包"))
        XCTAssertNil(VeilAppControlParser.parse("自动停止对方手机"))
        XCTAssertNil(VeilAppControlParser.parse("自动删除聊天"))
        XCTAssertNil(VeilAppControlParser.parse("自动发送消息"))
    }
}
