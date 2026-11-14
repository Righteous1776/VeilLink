import XCTest
@testable import VeilopolyNet

final class RoomLinkPolicyTests: XCTestCase {
 func testHealthyEncryptedSessionIsNotDisconnectedBySilentGame() {
  for gap in [0.0, 15.0, 15.1, 120.0, 3_600.0, .infinity, .nan] {
   XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldPauseGame(
    secureSessionReady: true, secondsSincePeer: gap))
  }
 }
 func testUnavailableEncryptedSessionPausesGame() {
  XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldPauseGame(
   secureSessionReady: false, secondsSincePeer: 0))
 }
 func testSilenceTriggersSyncProbeButNotDisconnect() {
  XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
   secureSessionReady: true, secondsSincePeer: 15))
  XCTAssertTrue(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
   secureSessionReady: true, secondsSincePeer: 16))
  XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
   secureSessionReady: false, secondsSincePeer: 16))
  XCTAssertFalse(VeilopolyRoomLinkPolicy.shouldProbeGameSync(
   secureSessionReady: true, secondsSincePeer: .infinity))
 }
}
