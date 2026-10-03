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

    @MainActor
    func testUICommandRequiresRequestIDAndDoesNotCreateReceiptWithoutConsumer() async {
        DeviceStressCommandBus.resetReceiptsForTesting()
        let request = DeviceStressCommandBus.post(.chatOpenFirstConversation)
        let receipt = await DeviceStressCommandBus.waitForReceipt(
            requestID: request.id,
            timeoutMilliseconds: 1
        )
        XCTAssertNil(receipt)

        let legacyNotification = Notification(
            name: .veilLinkStressUICommand,
            object: nil,
            userInfo: ["command": DeviceStressUICommand.chatOpenFirstConversation.rawValue]
        )
        XCTAssertNil(DeviceStressCommandBus.request(from: legacyNotification))
    }

    @MainActor
    func testUICommandReceiptMustMatchMountedConsumerDisposition() async {
        DeviceStressCommandBus.resetReceiptsForTesting()
        let request = DeviceStressCommandBus.post(.settingsOpenBackup)
        DeviceStressCommandBus.acknowledge(
            request,
            disposition: .ignored,
            detail: "presentation binding did not retain state"
        )

        let receipt = await DeviceStressCommandBus.waitForReceipt(
            requestID: request.id,
            timeoutMilliseconds: 1
        )
        XCTAssertEqual(receipt?.request, request)
        XCTAssertEqual(receipt?.disposition, .ignored)
        XCTAssertEqual(receipt?.detail, "presentation binding did not retain state")
    }
}
