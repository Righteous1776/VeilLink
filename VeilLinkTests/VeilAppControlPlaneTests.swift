import XCTest
@testable import VeilLink

final class VeilAppControlPlaneTests: XCTestCase {
    func testLegacyCommandsRemainCompatible() {
        XCTAssertEqual(VeilAppControlParser.parse("/ble refresh"), .refreshBLE)
        XCTAssertEqual(VeilAppControlParser.parse("检查数据库完整性"), .databaseIntegrity)
        XCTAssertEqual(VeilAppControlParser.parse("查看 A9 状态"), .a9Status)
        XCTAssertEqual(VeilAppControlParser.parse("/game move"), .executeSuggestedGameMove)
    }

    func testNaturalLanguageControlsMapToStructuredCommands() {
        XCTAssertEqual(VeilAppControlParser.parse("重新扫描附近设备"), .refreshBLE)
        XCTAssertEqual(VeilAppControlParser.parse("省电一点"), .restoreAutomaticPerformance)
        XCTAssertEqual(VeilAppControlParser.parse("清理缓存"), .trimCaches)
        XCTAssertEqual(VeilAppControlParser.parse("打开游戏"), .navigate(.games))
        XCTAssertEqual(VeilAppControlParser.parse("关闭自动保存图片"), .setAutoSaveReceivedImages(false))
    }

    func testReadOnlyAndNavigationRemainAvailableWhenMutationsAreDisabled() {
        let permissions = VeilAppControlPermissions(
            localMutationsEnabled: false,
            diagnosticsExportEnabled: false,
            suggestedMoveExecutionEnabled: false,
            autoRegulationMode: .off
        )
        XCTAssertTrue(VeilAppControlPolicy.authorize(.overviewStatus, permissions: permissions).allowed)
        XCTAssertTrue(VeilAppControlPolicy.authorize(.navigate(.settings), permissions: permissions).allowed)
        XCTAssertFalse(VeilAppControlPolicy.authorize(.refreshBLE, permissions: permissions).allowed)
        XCTAssertFalse(VeilAppControlPolicy.authorize(.trimCaches, permissions: permissions).allowed)
        XCTAssertFalse(VeilAppControlPolicy.authorize(.executeSuggestedGameMove, permissions: permissions).allowed)
    }

    func testGameExecutionUsesItsOwnExplicitPermission() {
        let permissions = VeilAppControlPermissions(
            localMutationsEnabled: false,
            diagnosticsExportEnabled: false,
            suggestedMoveExecutionEnabled: true,
            autoRegulationMode: .off
        )
        XCTAssertTrue(
            VeilAppControlPolicy.authorize(.executeSuggestedGameMove, permissions: permissions).allowed
        )
    }

    func testDestructiveOrRemoteControlPhrasesAreNotCommands() {
        XCTAssertNil(VeilAppControlParser.parse("删除数据库"))
        XCTAssertNil(VeilAppControlParser.parse("删除身份"))
        XCTAssertNil(VeilAppControlParser.parse("导出私钥"))
        XCTAssertNil(VeilAppControlParser.parse("替我发消息"))
        XCTAssertNil(VeilAppControlParser.parse("远程控制对方手机"))
        XCTAssertNil(VeilAppControlParser.parse("打开上帝模式"))
    }
}
