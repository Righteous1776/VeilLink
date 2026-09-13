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
        XCTAssertLessThan(legacy.targetBurstBytes, modern.targetBurstBytes)
        XCTAssertGreaterThan(legacy.interBurstDelay, modern.interBurstDelay)
    }

    func testBurstLimitAdaptsToNegotiatedPacketSizeAndByteBudget() {
        let tuning = BLELinkReliabilityPolicy.tuning(rssi: -55, machineIdentifier: "iPhone9,1")
        let legacyMTU = BLELinkReliabilityPolicy.effectivePacketBurstLimit(tuning: tuning, maximumPacketSize: 20)
        let wideMTU = BLELinkReliabilityPolicy.effectivePacketBurstLimit(tuning: tuning, maximumPacketSize: 185)

        XCTAssertEqual(legacyMTU, tuning.packetBurstLimit)
        XCTAssertLessThan(wideMTU, legacyMTU)
        XCTAssertGreaterThan(wideMTU, 16)
        XCTAssertLessThanOrEqual(wideMTU * 185, tuning.targetBurstBytes)
        XCTAssertEqual(BLELinkReliabilityPolicy.effectivePacketBurstLimit(tuning: tuning, maximumPacketSize: 0), 1)
    }

    func testStrongLinksReceiveMoreBurstCapacityThanWeakLinks() {
        let strong = BLELinkReliabilityPolicy.tuning(rssi: -50, machineIdentifier: "iPhone14,2")
        let weak = BLELinkReliabilityPolicy.tuning(rssi: -95, machineIdentifier: "iPhone14,2")
        XCTAssertGreaterThan(strong.packetBurstLimit, weak.packetBurstLimit)
        XCTAssertGreaterThan(strong.targetBurstBytes, weak.targetBurstBytes)
    }

    func testControlLaneCanOverflowABulkFilledQueueWithoutShrinkingBulkCapacity() {
        let packetLimit = 8_192
        let byteLimit = 640_000
        let budget = BLELinkReliabilityPolicy.queueBudget(packetLimit: packetLimit, byteLimit: byteLimit)

        XCTAssertGreaterThan(budget.controlOverflowPackets, 0)
        XCTAssertGreaterThan(budget.controlOverflowBytes, 0)

        // Legacy media behavior is preserved: bulk may still use the original full queue cap.
        XCTAssertTrue(BLELinkReliabilityPolicy.canEnqueue(
            priority: .bulk,
            pendingPackets: 0,
            pendingBytes: 0,
            additionalPackets: packetLimit,
            additionalBytes: byteLimit,
            packetLimit: packetLimit,
            byteLimit: byteLimit
        ))

        // Once bulk is full, only control traffic can use the emergency overflow lane.
        XCTAssertFalse(BLELinkReliabilityPolicy.canEnqueue(
            priority: .bulk,
            pendingPackets: packetLimit,
            pendingBytes: byteLimit,
            additionalPackets: 1,
            additionalBytes: 1,
            packetLimit: packetLimit,
            byteLimit: byteLimit
        ))
        XCTAssertTrue(BLELinkReliabilityPolicy.canEnqueue(
            priority: .control,
            pendingPackets: packetLimit,
            pendingBytes: byteLimit,
            additionalPackets: min(32, budget.controlOverflowPackets),
            additionalBytes: min(8_192, budget.controlOverflowBytes),
            packetLimit: packetLimit,
            byteLimit: byteLimit
        ))
    }

    func testControlTrafficTriggersFasterStallRecovery() {
        XCTAssertLessThan(
            BLELinkReliabilityPolicy.stallTimeout(quality: .marginal, hasControlTraffic: true),
            BLELinkReliabilityPolicy.stallTimeout(quality: .marginal, hasControlTraffic: false)
        )
        XCTAssertEqual(BLELinkReliabilityPolicy.stallTimeout(quality: .good, hasControlTraffic: true), 5)
        XCTAssertEqual(BLELinkReliabilityPolicy.stallTimeout(quality: .weak, hasControlTraffic: true), 9)
    }

    func testReconnectBackoffNeverStopsAndCapsAtThirtySeconds() {
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 1), 0.5)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 3), 2)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 6), 15)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 7), 24)
        XCTAssertEqual(BLELinkReliabilityPolicy.reconnectDelay(attempt: 100), 30)
    }
}
