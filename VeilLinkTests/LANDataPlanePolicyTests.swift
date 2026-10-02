import XCTest
@testable import VeilLink

final class LANDataPlanePolicyTests: XCTestCase {
    func testLANRanksAboveBLEAndRelay() {
        XCTAssertGreaterThan(VeilTransportRoutePolicy.rank(.lan), VeilTransportRoutePolicy.rank(.ble))
        XCTAssertGreaterThan(VeilTransportRoutePolicy.rank(.ble), VeilTransportRoutePolicy.rank(.internet))
    }

    func testLANUsesBoundedBurstWindow() {
        XCTAssertEqual(LANDataPlanePolicy.attachmentBurstWindow, 4)
        XCTAssertGreaterThan(LANDataPlanePolicy.attachmentBurstWindow, 1)
        XCTAssertLessThanOrEqual(LANDataPlanePolicy.attachmentBurstWindow, 8)
    }

    func testReconnectBackoffIsBoundedAndMonotonic() {
        let delays = (0..<8).map { LANDataPlanePolicy.reconnectDelay(attempt: $0) }
        XCTAssertEqual(delays.first ?? 99, 0.35, accuracy: 0.001)
        XCTAssertLessThanOrEqual(delays.last ?? 99, 5.0)
        for pair in zip(delays, delays.dropFirst()) { XCTAssertLessThanOrEqual(pair.0, pair.1) }
    }

    func testBulkTrafficLeavesInteractiveQueueHeadroom() {
        let maximumFrames = 256
        let maximumBytes = 8 * 1_024 * 1_024
        let bulkFrameLimit = maximumFrames - LANDataPlanePolicy.interactiveReserveFrames
        let bulkByteLimit = maximumBytes - LANDataPlanePolicy.interactiveReserveBytes

        XCTAssertTrue(LANDataPlanePolicy.canEnqueue(
            priority: .bulk,
            queuedFrames: bulkFrameLimit - 1,
            queuedBytes: bulkByteLimit - 50_000,
            inFlightFrames: 0,
            inFlightBytes: 0,
            additionalBytes: 50_000,
            maximumFrames: maximumFrames,
            maximumBytes: maximumBytes
        ))
        XCTAssertFalse(LANDataPlanePolicy.canEnqueue(
            priority: .bulk,
            queuedFrames: bulkFrameLimit,
            queuedBytes: bulkByteLimit,
            inFlightFrames: 0,
            inFlightBytes: 0,
            additionalBytes: 1,
            maximumFrames: maximumFrames,
            maximumBytes: maximumBytes
        ))
        XCTAssertTrue(LANDataPlanePolicy.canEnqueue(
            priority: .control,
            queuedFrames: bulkFrameLimit,
            queuedBytes: bulkByteLimit,
            inFlightFrames: 0,
            inFlightBytes: 0,
            additionalBytes: 50_000,
            maximumFrames: maximumFrames,
            maximumBytes: maximumBytes
        ))
    }

    func testAdmissionIncludesFramesAlreadyInFlight() {
        XCTAssertFalse(LANDataPlanePolicy.canEnqueue(
            priority: .control,
            queuedFrames: 7,
            queuedBytes: 700,
            inFlightFrames: 2,
            inFlightBytes: 200,
            additionalBytes: 100,
            maximumFrames: 9,
            maximumBytes: 1_000
        ))
        XCTAssertGreaterThanOrEqual(LANDataPlanePolicy.sendStallTimeout, 5)
        XCTAssertLessThanOrEqual(LANDataPlanePolicy.sendStallTimeout, 30)
    }
}
