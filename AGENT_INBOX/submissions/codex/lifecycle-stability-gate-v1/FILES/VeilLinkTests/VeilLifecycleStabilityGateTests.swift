import XCTest
@testable import VeilLink

final class VeilLifecycleStabilityGateTests: XCTestCase {
    func testInitialActiveAppearanceStartsAndForegroundsOnce() {
        var gate = VeilLifecycleStabilityGate()
        XCTAssertEqual(gate.consume(.rootAppeared(.active)), [
            .attachRuntime, .startRuntime, .setHostForeground(true), .enterForeground
        ])
        XCTAssertEqual(gate.consume(.rootAppeared(.active)), [])
        XCTAssertEqual(gate.consume(.sceneChanged(.active)), [])
    }

    func testNormalBackgroundRoundTripPreservesActionOrder() {
        var gate = VeilLifecycleStabilityGate()
        _ = gate.consume(.rootAppeared(.active))
        XCTAssertEqual(gate.consume(.sceneChanged(.inactive)), [
            .setHostForeground(false), .prepareBackground
        ])
        XCTAssertEqual(gate.consume(.sceneChanged(.background)), [.enterBackground])
        XCTAssertEqual(gate.consume(.sceneChanged(.active)), [
            .setHostForeground(true), .enterForeground
        ])
    }

    func testDirectActiveToBackgroundStillPreparesBeforeEntering() {
        var gate = VeilLifecycleStabilityGate()
        _ = gate.consume(.rootAppeared(.active))
        XCTAssertEqual(gate.consume(.sceneChanged(.background)), [
            .setHostForeground(false), .prepareBackground, .enterBackground
        ])
    }

    func testRepeatedInactiveAndBackgroundEventsAreIgnored() {
        var gate = VeilLifecycleStabilityGate()
        _ = gate.consume(.rootAppeared(.active))
        _ = gate.consume(.sceneChanged(.inactive))
        XCTAssertEqual(gate.consume(.sceneChanged(.inactive)), [])
        _ = gate.consume(.sceneChanged(.background))
        XCTAssertEqual(gate.consume(.sceneChanged(.background)), [])
    }

    func testMemoryWarningBurstIsCoalescedButLaterWarningRuns() {
        var gate = VeilLifecycleStabilityGate()
        _ = gate.consume(.rootAppeared(.active))
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: 100)), [.handleMemoryPressure])
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: 100.5)), [])
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: 102)), [.handleMemoryPressure])
    }

    func testWarningsBeforeRuntimeAndInvalidUptimeAreIgnored() {
        var gate = VeilLifecycleStabilityGate()
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: 10)), [])
        _ = gate.consume(.rootAppeared(.inactive))
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: .nan)), [])
        XCTAssertEqual(gate.consume(.memoryWarning(uptime: -1)), [])
    }

    func testSceneChangeBeforeRootDoesNotStartRuntime() {
        var gate = VeilLifecycleStabilityGate()
        XCTAssertEqual(gate.consume(.sceneChanged(.background)), [])
        XCTAssertEqual(gate.consume(.rootAppeared(.background)), [
            .attachRuntime, .startRuntime, .setHostForeground(false),
            .prepareBackground, .enterBackground
        ])
    }
}
