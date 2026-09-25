import CryptoKit
import XCTest
@testable import VeilLink

final class RemotePairingTests: XCTestCase {
    func testQRCodeExpiresAfterSixtySeconds() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: key.publicKey.rawRepresentation, now: now)
        XCTAssertNoThrow(try VeilRemotePairCrypto.validate(qr, now: now.addingTimeInterval(59)))
        XCTAssertThrowsError(try VeilRemotePairCrypto.validate(qr, now: now.addingTimeInterval(61)))
    }

    func testBothSidesDeriveSamePairSecretAndSAS() throws {
        let initiatorEphemeral = Curve25519.KeyAgreement.PrivateKey()
        let responderEphemeral = Curve25519.KeyAgreement.PrivateKey()
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: initiatorEphemeral.publicKey.rawRepresentation)
        let initiatorIdentity = CryptoEngine.newIdentityKey()
        let responderIdentity = CryptoEngine.newIdentityKey()
        let initiatorID = CryptoEngine.identityID(publicKey: initiatorIdentity.publicKey.rawRepresentation)
        let responderID = CryptoEngine.identityID(publicKey: responderIdentity.publicKey.rawRepresentation)
        let a = try VeilRemotePairCrypto.finalPairSecret(
            localEphemeralPrivateKey: initiatorEphemeral,
            remoteEphemeralPublicKey: responderEphemeral.publicKey.rawRepresentation,
            qr: qr,
            initiatorIdentityID: initiatorID,
            responderIdentityID: responderID,
            initiatorPublicKey: initiatorIdentity.publicKey.rawRepresentation,
            responderPublicKey: responderIdentity.publicKey.rawRepresentation
        )
        let b = try VeilRemotePairCrypto.finalPairSecret(
            localEphemeralPrivateKey: responderEphemeral,
            remoteEphemeralPublicKey: initiatorEphemeral.publicKey.rawRepresentation,
            qr: qr,
            initiatorIdentityID: initiatorID,
            responderIdentityID: responderID,
            initiatorPublicKey: initiatorIdentity.publicKey.rawRepresentation,
            responderPublicKey: responderIdentity.publicKey.rawRepresentation
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(
            VeilRemotePairCrypto.sas(pairSecret: a, offerID: qr.offerID, initiatorIdentityID: initiatorID, responderIdentityID: responderID),
            VeilRemotePairCrypto.sas(pairSecret: b, offerID: qr.offerID, initiatorIdentityID: initiatorID, responderIdentityID: responderID)
        )
    }


    func testQRCodeCodecRoundTrip() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: key.publicKey.rawRepresentation, now: now)
        let encoded = try VeilRemotePairQRCodeCodec.encode(qr)
        XCTAssertTrue(encoded.hasPrefix("veillink://pair?v=1&d="))
        let decoded = try VeilRemotePairQRCodeCodec.decode(encoded, now: now.addingTimeInterval(5))
        XCTAssertEqual(decoded, qr)
    }

    func testProviderAndDirectionRoutesAreSeparated() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: key.publicKey.rawRepresentation)
        let cnIn = try VeilRemotePairCrypto.route(qr: qr, region: .domestic, direction: .toInitiator)
        let cnOut = try VeilRemotePairCrypto.route(qr: qr, region: .domestic, direction: .toResponder)
        let globalIn = try VeilRemotePairCrypto.route(qr: qr, region: .international, direction: .toInitiator)
        XCTAssertNotEqual(cnIn.mailbox, cnOut.mailbox)
        XCTAssertNotEqual(cnIn.readToken, cnOut.readToken)
        XCTAssertNotEqual(cnIn.mailbox, globalIn.mailbox)
        XCTAssertNotEqual(cnIn.writeToken, globalIn.writeToken)
    }

    func testRelayPacketCarriesEncryptedLogicalDedupID() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: key.publicKey.rawRepresentation)
        let logicalID = UUID().uuidString
        let packet = VeilRemotePairRelayPacket(
            version: VeilRemotePairCrypto.version, kind: .reject, logicalPacketID: logicalID,
            offerID: qr.offerID, claimID: UUID().uuidString, responderEphemeralPublicKey: nil,
            innerCiphertext: Data([1, 2, 3]), sentAt: Date()
        )
        let sealed = try VeilRemotePairCrypto.sealRelayPacket(packet, qr: qr, region: .domestic, direction: .toInitiator)
        let opened = try VeilRemotePairCrypto.openRelayPacket(sealed, qr: qr, region: .domestic, direction: .toInitiator)
        XCTAssertEqual(opened.logicalPacketID, logicalID)
    }

    func testProviderRoutesAreSeparated() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: key.publicKey.rawRepresentation)
        let cn = try VeilRemotePairCrypto.route(qr: qr, region: .domestic, direction: .toInitiator)
        let global = try VeilRemotePairCrypto.route(qr: qr, region: .international, direction: .toInitiator)
        XCTAssertNotEqual(cn.mailbox, global.mailbox)
        XCTAssertNotEqual(cn.readToken, global.readToken)
    }
}
