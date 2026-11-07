import XCTest
@testable import VeilLink

final class DeepTelemetryBrightnessSnapshotPolicyTests: XCTestCase {
    func testFirstValidReadingIsRecorded() {
        XCTAssertTrue(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.70, previousBrightness: nil,
            nowUptime: 100, previousUptime: nil
        ))
    }

    func testAutoBrightnessMicroChangesAreCoalesced() {
        XCTAssertFalse(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.71, previousBrightness: 0.70,
            nowUptime: 102.1, previousUptime: 100
        ))
        XCTAssertFalse(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.75, previousBrightness: 0.70,
            nowUptime: 101.5, previousUptime: 100
        ))
        XCTAssertTrue(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.75, previousBrightness: 0.70,
            nowUptime: 102.1, previousUptime: 100
        ))
    }

    func testPolicyRejectsInvalidAndReorderedSamples() {
        XCTAssertFalse(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: -0.1, previousBrightness: nil,
            nowUptime: 100, previousUptime: nil
        ))
        XCTAssertFalse(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.9, previousBrightness: 0.1,
            nowUptime: 99, previousUptime: 100
        ))
        XCTAssertFalse(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: .infinity, previousBrightness: nil,
            nowUptime: 100, previousUptime: nil
        ))
    }

    func testThresholdAndBoundaryAreInclusive() {
        XCTAssertEqual(DeepTelemetryBrightnessSnapshotPolicy.minimumInterval, 2.0)
        XCTAssertEqual(DeepTelemetryBrightnessSnapshotPolicy.minimumBrightnessDelta, 0.02)
        XCTAssertTrue(DeepTelemetryBrightnessSnapshotPolicy.shouldCapture(
            brightness: 0.52, previousBrightness: 0.50,
            nowUptime: 102, previousUptime: 100
        ))
    }
}
