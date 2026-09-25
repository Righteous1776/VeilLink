import XCTest
@testable import VeilLink

final class BLELinkReliabilityPolicyTests: XCTestCase {
    func testRSSIQualityBands() {
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -55), .strong)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -62), .strong)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -63), .good)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -72), .good)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -73), .marginal)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -82), .marginal)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: -83), .weak)
        XCTAssertEqual(BLELinkReliabilityPolicy.quality(rssi: nil), .unknown)
    }

    func testInvalidRSSISamplesDoNotPoisonSmoothing() {
        XCTAssertNil(BLELinkReliabilityPolicy.normalizedRSSI(127))
        XCTAssertNil(BLELinkReliabilityPolicy.normalizedRSSI(0))
        XCTAssertNil(BLELinkReliabilityPolicy.normalizedRSSI(-111))
        XCTAssertEqual(BLELinkReliabilityPolicy.normalizedRSSI(-5), -20)
        XCTAssertEqual(BLELinkReliabilityPolicy.smoothedRSSI(previous: -70, sample: 127), -70)
    }

    func testLegacyDevicesPaceMarginalLinksMoreConservatively() {
        let legacy = BLELinkReliabilityPolicy.tuning(rssi: -79, machineIdentifier: "iPhone9,1")
        let modern = BLELinkReliabilityPolicy.tuning(rssi: -79, machineIdentifier: "iPhone14,2")

        XCTAssertEqual(legacy.quality, .marginal)
        XCTAssertEqual(modern.quality, .marginal)
        XCTAssertLessThan(legacy.packetBurstLimit, modern.packetBurstLimit)
        XCTAssertGreaterThan(legacy.interBurstDelay, modern.interBurstDelay)
    }

    func testStrongLinksReceiveMoreBurstCapacityThanWeakLinks() {
        let strong = BLELinkReliabilityPolicy.tuning(rssi: -50, machineIdentifier: "iPhone14,2")
        let weak = BLELinkReliabilityPolicy.tuning(rssi: -95, machineIdentifier: "iPhone14,2")

        XCTAssertEqual(strong.quality, .strong)
        XCTAssertEqual(weak.quality, .weak)
        XCTAssertGreaterThan(strong.packetBurstLimit, weak.packetBurstLimit)
        XCTAssertLessThan(strong.interBurstDelay, weak.interBurstDelay)
    }

    func testLegacyUnknownLinkUsesMoreConservativeDefaultsThanModernDevice() {
        let legacy = BLELinkReliabilityPolicy.tuning(rssi: nil, machineIdentifier: "iPhone9,1")
        let modern = BLELinkReliabilityPolicy.tuning(rssi: nil, machineIdentifier: "iPhone14,2")

        XCTAssertEqual(legacy.quality, .unknown)
        XCTAssertEqual(modern.quality, .unknown)
        XCTAssertLessThan(legacy.packetBurstLimit, modern.packetBurstLimit)
        XCTAssertGreaterThan(legacy.interBurstDelay, modern.interBurstDelay)
    }

    func testReconnectBackoffProgressesAndCapsAtThirtySeconds() {
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 0), 0.75)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 1), 0.75)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 2), 1.5)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 3), 3)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 4), 6)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 5), 12)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 6), 20)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 7), 30)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 100), 30)
    }
}
