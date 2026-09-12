import XCTest
@testable import VeilLink

final class BLELinkReliabilityPolicyTests: XCTestCase {
    func testRSSIQualityBands() {
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -55), .strong)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -68), .good)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -78), .marginal)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -91), .weak)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: nil), .unknown)
    }

    func testInvalidRSSISamplesDoNotPoisonSmoothing() {
        XCTAssertNil(BLELinkReliabilityPolicy.normalizedRSSI(127))
        XCTAssertNil(BLELinkReliabilityPolicy.normalizedRSSI(0))
        XCTAssertEqual(BLELinkReliabilityPolicy.smoothedRSSI(previous: -70, sample: 127), -70)
    }

    func testLegacyDevicesPaceMarginalLinksMoreConservatively() {
        let legacy = BLELinkReliabilityPolicy.tuning(rssi: -79, machineIdentifier: "iPhone9,1")
        let modern = BLELinkReliabilityPolicy.tuning(rssi: -79, machineIdentifier: "iPhone14,2")
        XCTAssertEqual(legacy.quality, .marginal)
        XCTAssertLessThan(legacy.packetBurstLimit, modern.packetBurstLimit)
        XCTAssertGreaterThan(legacy.interBurstDelay, modern.interBurstDelay)
    }

    func testReconnectBackoffNeverStopsAndCapsAtThirtySeconds() {
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 1), 0.75)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 6), 20)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 7), 30)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 100), 30)
    }
}
