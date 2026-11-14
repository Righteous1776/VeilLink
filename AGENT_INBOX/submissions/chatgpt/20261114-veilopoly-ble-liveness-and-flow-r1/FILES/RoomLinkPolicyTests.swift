import XCTest
@testable import VeilopolyNet

final class RoomLinkPolicyTests: XCTestCase {
    func testHealthySecureSessionNeverPausesOnlyForSilentGameHeartbeats() {
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: true, secondsSincePeer: 0))
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: true, secondsSincePeer: 16))
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: true, secondsSincePeer: 300))
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: true, secondsSincePeer: .infinity))
    }

    func testActualSecureSessionLossPausesGameRegardlessOfHeartbeat() {
        XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: false, secondsSincePeer: 0))
        XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldPauseGame(
            secureSessionReady: false, secondsSincePeer: 300))
    }

    func testSilentButSecureLinkOnlyRequestsStatusProbe() {
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
            secureSessionReady: true, secondsSincePeer: 15))
        XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
            secureSessionReady: true, secondsSincePeer: 15.001))
        XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
            secureSessionReady: true, secondsSincePeer: .nan))
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
            secureSessionReady: false, secondsSincePeer: 20))
    }

    func testGameMonitorNeverResetsSharedSecurityWithoutUserAction() {
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldRequestSecureRecovery(
            secureSessionReady: false, userInitiated: false))
        XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldRequestSecureRecovery(
            secureSessionReady: true, userInitiated: true))
        XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldRequestSecureRecovery(
            secureSessionReady: false, userInitiated: true))
    }
}
