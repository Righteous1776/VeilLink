import XCTest
@testable import VeilLink

final class BLEGattHandshakeWatchdogTests: XCTestCase {
    func testPhysicalConnectionRemainsPendingUntilGattReady() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(peer, uptime: 100)
        XCTAssertEqual(monitor.pendingCount, 1)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 144.999).isEmpty)
        XCTAssertEqual(monitor.timedOutPeerIDs(uptime: 145), [peer])
        monitor.dataChannelReady(peer)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 999).isEmpty)
        XCTAssertEqual(monitor.pendingCount, 0)
    }

    func testDisconnectClearsOnlyThatPeer() {
        let a = UUID(), b = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(a, uptime: 10)
        monitor.physicalLinkConnected(b, uptime: 20)
        monitor.disconnected(a)
        XCTAssertEqual(monitor.timedOutPeerIDs(uptime: 70), [b])
    }

    func testMultiplePeersAreIndependentAndDeterministicallyOrdered() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(b, uptime: 10)
        monitor.physicalLinkConnected(a, uptime: 10)
        XCTAssertEqual(monitor.timedOutPeerIDs(uptime: 55), [a, b])
        monitor.dataChannelReady(a)
        XCTAssertEqual(monitor.timedOutPeerIDs(uptime: 56), [b])
    }

    func testNoTimeoutIfMonotonicClockMovesBackwards() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(peer, uptime: 120)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 80).isEmpty)
    }

    func testReconnectStartsNewHandshakeEpoch() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(peer, uptime: 100)
        monitor.disconnected(peer)
        monitor.physicalLinkConnected(peer, uptime: 200)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 240).isEmpty)
        XCTAssertEqual(monitor.timedOutPeerIDs(uptime: 245), [peer])
    }

    func testResetAllDropsRestoredAndPendingEpochs() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(peer, uptime: 1)
        monitor.resetAll()
        XCTAssertEqual(monitor.pendingCount, 0)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 500).isEmpty)
    }

    func testInvalidUptimeAndTimeoutCannotTriggerRecovery() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.physicalLinkConnected(peer, uptime: .nan)
        XCTAssertEqual(monitor.pendingCount, 0)
        monitor.physicalLinkConnected(peer, uptime: 10)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: .nan).isEmpty)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: .infinity).isEmpty)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 100, timeout: 0).isEmpty)
        XCTAssertTrue(monitor.timedOutPeerIDs(uptime: 100, timeout: -.infinity).isEmpty)
    }

    func testIdempotentCompletionAndDisconnect() {
        let peer = UUID()
        var monitor = BLEGattHandshakeWatchdog()
        monitor.dataChannelReady(peer)
        monitor.disconnected(peer)
        monitor.physicalLinkConnected(peer, uptime: 10)
        monitor.dataChannelReady(peer)
        monitor.dataChannelReady(peer)
        XCTAssertEqual(monitor.pendingCount, 0)
    }
}
