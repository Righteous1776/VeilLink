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
}
