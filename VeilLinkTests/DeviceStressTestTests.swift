import XCTest
@testable import VeilLink

final class DeviceStressTestTests: XCTestCase {
    func testPresetDefaultsAreBoundedAndDistinct() {
        let quick = DeviceStressConfiguration.defaults(for: .quick)
        let standard = DeviceStressConfiguration.defaults(for: .standard)
        let extreme = DeviceStressConfiguration.defaults(for: .extreme)
        let endurance = DeviceStressConfiguration.defaults(for: .endurance)

        XCTAssertEqual(quick.requestedCycles, 3)
        XCTAssertEqual(standard.requestedCycles, 20)
        XCTAssertEqual(extreme.requestedCycles, 100)
        XCTAssertEqual(endurance.requestedCycles, 0)
        XCTAssertGreaterThanOrEqual(quick.stepDelayMilliseconds, 15)
        XCTAssertGreaterThanOrEqual(standard.stepDelayMilliseconds, 15)
        XCTAssertGreaterThanOrEqual(extreme.stepDelayMilliseconds, 15)
        XCTAssertGreaterThanOrEqual(endurance.stepDelayMilliseconds, 15)
        XCTAssertLessThan(extreme.stepDelayMilliseconds, standard.stepDelayMilliseconds)
    }

    func testStressCommandsRoundTripRawValues() {
        let commands: [DeviceStressUICommand] = [
            .settingsOpenIdentity,
            .settingsOpenAppLock,
            .settingsOpenBackup,
            .settingsClosePresentations,
            .agentOpenDiagnostics,
            .agentCloseDiagnostics,
            .chatOpenFirstConversation,
            .chatCloseConversation
        ]
        for command in commands {
            XCTAssertEqual(DeviceStressUICommand(rawValue: command.rawValue), command)
        }
    }
}
