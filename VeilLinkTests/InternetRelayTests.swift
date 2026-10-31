import CryptoKit
import XCTest
@testable import VeilLink

final class InternetRelayTests: XCTestCase {
    func testFirstTransientFailureKeepsReachableProviderAvailable() {
        let initial = VeilRelayProviderSnapshot(
            region: .domestic,
            reachable: true,
            roundTripMilliseconds: 42,
            lastSuccessAt: Date(),
            consecutiveFailures: 0
        )

        let failedOnce = VeilRelayProviderHealthPolicy.recordingFailure(initial)

        XCTAssertTrue(failedOnce.reachable)
        XCTAssertEqual(failedOnce.consecutiveFailures, 1)
    }

    func testConsecutiveFailuresEjectProviderAtThreshold() {
        let initial = VeilRelayProviderSnapshot(
            region: .international,
            reachable: true,
            roundTripMilliseconds: 80,
            lastSuccessAt: Date(),
            consecutiveFailures: 0
        )

        let failedOnce = VeilRelayProviderHealthPolicy.recordingFailure(initial)
        let failedTwice = VeilRelayProviderHealthPolicy.recordingFailure(failedOnce)

        XCTAssertFalse(failedTwice.reachable)
        XCTAssertEqual(failedTwice.consecutiveFailures, VeilRelayProviderHealthPolicy.consecutiveFailureThreshold)
    }

    func testProviderSeparatedRoutes() throws {
        let secret = Data(repeating: 0x31, count: 32)
        let cn = try VeilRelayCrypto.route(pairSecret: secret, senderIdentityID: "A", receiverIdentityID: "B", provider: .domestic, epoch: 100)
        let global = try VeilRelayCrypto.route(pairSecret: secret, senderIdentityID: "A", receiverIdentityID: "B", provider: .international, epoch: 100)
        XCTAssertNotEqual(cn.mailboxID, global.mailboxID)
        XCTAssertNotEqual(cn.readToken, global.readToken)
        XCTAssertNotEqual(cn.writeToken, global.writeToken)
    }

    func testOuterEncryptionRoundTrip() throws {
        let secret = Data(repeating: 0x72, count: 32)
        let wire = Data((0..<4096).map { UInt8($0 & 0xff) })
        let deliveryID = UUID().uuidString
        let body = try VeilRelayCrypto.seal(
            wireEnvelope: wire, deliveryID: deliveryID, pairSecret: secret,
            senderIdentityID: "LOCAL", receiverIdentityID: "PEER",
            provider: .international, epoch: 22, sentAt: Date()
        )
        let clear = try VeilRelayCrypto.open(
            body: body, pairSecret: secret,
            senderIdentityID: "LOCAL", receiverIdentityID: "PEER",
            provider: .international, epoch: 22
        )
        XCTAssertEqual(clear.deliveryID, deliveryID)
        XCTAssertEqual(clear.wireEnvelope, wire)
    }

    func testDirectionAndEpochChangeOuterCiphertext() throws {
        let secret = Data(repeating: 0x19, count: 32)
        let wire = Data("hello".utf8)
        let id = UUID().uuidString
        let a = try VeilRelayCrypto.seal(wireEnvelope: wire, deliveryID: id, pairSecret: secret, senderIdentityID: "A", receiverIdentityID: "B", provider: .domestic, epoch: 1)
        let b = try VeilRelayCrypto.seal(wireEnvelope: wire, deliveryID: id, pairSecret: secret, senderIdentityID: "B", receiverIdentityID: "A", provider: .domestic, epoch: 1)
        let c = try VeilRelayCrypto.seal(wireEnvelope: wire, deliveryID: id, pairSecret: secret, senderIdentityID: "A", receiverIdentityID: "B", provider: .domestic, epoch: 2)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
