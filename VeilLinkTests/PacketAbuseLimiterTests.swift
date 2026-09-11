import XCTest
@testable import VeilLink

final class PacketAbuseLimiterTests: XCTestCase {
    func testLimiterDisconnectsOnlyAfterThresholdWithinWindow() {
        var limiter = PacketAbuseLimiter(windowDuration: 10, maximumPacketsPerWindow: 3)
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        let first = limiter.recordInvalidPacket(for: id, now: start)
        XCTAssertTrue(first.isFirstInWindow)
        XCTAssertFalse(first.shouldDisconnect)
        XCTAssertEqual(first.count, 1)

        XCTAssertFalse(limiter.recordInvalidPacket(for: id, now: start.addingTimeInterval(1)).shouldDisconnect)
        XCTAssertTrue(limiter.recordInvalidPacket(for: id, now: start.addingTimeInterval(2)).shouldDisconnect)
    }

    func testLimiterWindowExpiresAndSourcesAreIndependent() {
        var limiter = PacketAbuseLimiter(windowDuration: 5, maximumPacketsPerWindow: 2)
        let a = UUID()
        let b = UUID()
        let start = Date(timeIntervalSince1970: 2_000)

        _ = limiter.recordInvalidPacket(for: a, now: start)
        let bFirst = limiter.recordInvalidPacket(for: b, now: start)
        XCTAssertTrue(bFirst.isFirstInWindow)
        XCTAssertFalse(bFirst.shouldDisconnect)

        let aAfterExpiry = limiter.recordInvalidPacket(for: a, now: start.addingTimeInterval(6))
        XCTAssertTrue(aAfterExpiry.isFirstInWindow)
        XCTAssertFalse(aAfterExpiry.shouldDisconnect)
        XCTAssertEqual(aAfterExpiry.count, 1)
    }

    func testResetClearsPenaltyForSuccessfulTraffic() {
        var limiter = PacketAbuseLimiter(windowDuration: 10, maximumPacketsPerWindow: 2)
        let id = UUID()
        let now = Date()

        _ = limiter.recordInvalidPacket(for: id, now: now)
        limiter.reset(id)
        let next = limiter.recordInvalidPacket(for: id, now: now.addingTimeInterval(1))
        XCTAssertTrue(next.isFirstInWindow)
        XCTAssertFalse(next.shouldDisconnect)
    }
}
