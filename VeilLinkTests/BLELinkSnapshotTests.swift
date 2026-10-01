import XCTest
@testable import VeilLink

final class BLELinkSnapshotTests: XCTestCase {
    func testConnectedStrongLinkScoresHigherThanRecoveringWeakLink() {
        let id = UUID()
        let strong = BLEPeerLinkSnapshot(
            id: id, isConnected: true, isWanted: true, reconnectAttempt: 0,
            rssi: -55, quality: .strong, pendingPackets: 0, pendingBytes: 0,
            controlPendingPackets: 0, maximumPacketSize: 185, role: .central, transportStage: .gattReady, stalledFor: nil
        )
        let weak = BLEPeerLinkSnapshot(
            id: id, isConnected: false, isWanted: true, reconnectAttempt: 4,
            rssi: -92, quality: .weak, pendingPackets: 128, pendingBytes: 200_000,
            controlPendingPackets: 12, maximumPacketSize: 20, role: .unavailable, transportStage: .discovered, stalledFor: 8
        )
        XCTAssertGreaterThan(strong.healthScore, weak.healthScore)
        XCTAssertTrue(strong.statusTitle.contains("GATT_READY"))
        XCTAssertTrue(weak.statusTitle.contains("DISCOVERED"))
    }

    func testTransportStageDistinguishesPhysicalFromGATTReadiness() {
        let snapshot = BLEPeerLinkSnapshot(
            id: UUID(), isConnected: false, isWanted: true, reconnectAttempt: 0,
            rssi: -58, quality: .strong, pendingPackets: 0, pendingBytes: 0,
            controlPendingPackets: 0, maximumPacketSize: 185, role: .unavailable,
            transportStage: .phyConnected, stalledFor: nil
        )
        XCTAssertEqual(snapshot.transportStage, .phyConnected)
        XCTAssertTrue(snapshot.statusTitle.contains("PHY_CONNECTED"))
        XCTAssertFalse(snapshot.isConnected)
    }

    func testQueueSummaryCallsOutControlTraffic() {
        let snapshot = BLEPeerLinkSnapshot(
            id: UUID(), isConnected: true, isWanted: true, reconnectAttempt: 0,
            rssi: -70, quality: .good, pendingPackets: 30, pendingBytes: 16_384,
            controlPendingPackets: 4, maximumPacketSize: 185, role: .dual, transportStage: .gattReady, stalledFor: nil
        )
        XCTAssertTrue(snapshot.queueSummary.contains("控制 4"))
        XCTAssertTrue(snapshot.compactDetail.contains("ATT 185 B"))
    }

    func testDiagnosticsContainNoSensitivePayloadFields() {
        let report = BLELinkDiagnosticsFormatter.report(
            generatedAt: Date(timeIntervalSince1970: 0),
            isRunning: true,
            statusText: "加密蓝牙链路已就绪",
            connectedPeerCount: 1,
            snapshots: []
        )
        XCTAssertTrue(report.contains("Privacy:"))
        XCTAssertFalse(report.contains("PRIVATE_KEY"))
        XCTAssertFalse(report.contains("MESSAGE_BODY="))
    }
    func testPassiveDiscoveryDoesNotContributeToA9Health() {
        let passive = BLEPeerLinkSnapshot(
            id: UUID(), isConnected: false, isWanted: false, reconnectAttempt: 0,
            rssi: -98, quality: .weak, pendingPackets: 0, pendingBytes: 0,
            controlPendingPackets: 0, maximumPacketSize: nil, role: .unavailable,
            transportStage: .discovered, stalledFor: nil
        )
        let live = BLEPeerLinkSnapshot(
            id: UUID(), isConnected: true, isWanted: true, reconnectAttempt: 0,
            rssi: -72, quality: .good, pendingPackets: 0, pendingBytes: 0,
            controlPendingPackets: 0, maximumPacketSize: 185, role: .central,
            transportStage: .gattReady, stalledFor: nil
        )
        XCTAssertFalse(passive.isA9Relevant)
        XCTAssertFalse(passive.contributesLinkQualityToA9)
        XCTAssertTrue(live.isA9Relevant)
        XCTAssertTrue(live.contributesLinkQualityToA9)
    }

}
