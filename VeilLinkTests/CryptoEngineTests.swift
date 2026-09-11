import CryptoKit
import XCTest
@testable import VeilLink

final class CryptoEngineTests: XCTestCase {
    func testIdentityIDIsStable() {
        let key = CryptoEngine.newIdentityKey()
        let first = CryptoEngine.identityID(publicKey: key.publicKey.rawRepresentation)
        let second = CryptoEngine.identityID(publicKey: key.publicKey.rawRepresentation)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    func testTwoPeersDeriveSameSessionKeyAndPairingCode() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let transcript = Data("test-transcript".utf8)

        let aliceKey = try CryptoEngine.deriveSessionKey(
            localPrivateKey: alice,
            remotePublicKey: bob.publicKey.rawRepresentation,
            transcript: transcript
        )
        let bobKey = try CryptoEngine.deriveSessionKey(
            localPrivateKey: bob,
            remotePublicKey: alice.publicKey.rawRepresentation,
            transcript: transcript
        )
        XCTAssertEqual(
            aliceKey.withUnsafeBytes { Data($0) },
            bobKey.withUnsafeBytes { Data($0) }
        )
        XCTAssertEqual(
            CryptoEngine.pairingCode(key: aliceKey, transcript: transcript),
            CryptoEngine.pairingCode(key: bobKey, transcript: transcript)
        )
    }

    func testAuthenticatedEncryptionRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let cleartext = Data("只在两台设备之间出现".utf8)
        let payload = try CryptoEngine.encrypt(cleartext, key: key, messageID: "m1", sequence: 1)
        XCTAssertEqual(try CryptoEngine.decrypt(payload, key: key), cleartext)
    }

    func testBLEFramingRoundTrip() {
        let original = Data((0..<3_000).map { UInt8($0 % 251) })
        let fragments = BLEFragment.split(original, maximumPacketSize: 180)
        let assembler = BLEFragmentAssembler()
        var recovered: Data?
        let source = UUID()
        for fragment in fragments {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertEqual(recovered, original)
    }
    func testBLEFramingRejectsPacketSizeSmallerThanHeader() {
        XCTAssertTrue(BLEFragment.split(Data([1, 2, 3]), maximumPacketSize: BLEFragment.headerSize).isEmpty)
    }

    func testBLEAssemblerRejectsOversizedMessage() {
        let original = Data(repeating: 0xA5, count: 256)
        let fragments = BLEFragment.split(original, maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler(maxAssembledBytes: 128)
        let source = UUID()
        var recovered: Data?
        for fragment in fragments {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertNil(recovered)
    }

    func testBLEAssemblerAcceptsDuplicateFragmentOnlyWhenIdentical() {
        let original = Data(repeating: 0x11, count: 128)
        let fragments = BLEFragment.split(original, maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler()
        let source = UUID()
        XCTAssertNil(assembler.ingest(source: source, packet: fragments[0].encoded))
        XCTAssertNil(assembler.ingest(source: source, packet: fragments[0].encoded))
        var recovered: Data?
        for fragment in fragments.dropFirst() {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertEqual(recovered, original)
    }

}

extension CryptoEngineTests {
    func testDirectionalSessionKeysMirrorAcrossPeersButNotDirections() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey(); let bob = Curve25519.KeyAgreement.PrivateKey(); let transcript = Data("directional-transcript".utf8)
        let a = try CryptoEngine.deriveSessionKeys(localPrivateKey: alice, remotePublicKey: bob.publicKey.rawRepresentation, transcript: transcript, localIdentityID: "alice", remoteIdentityID: "bob")
        let b = try CryptoEngine.deriveSessionKeys(localPrivateKey: bob, remotePublicKey: alice.publicKey.rawRepresentation, transcript: transcript, localIdentityID: "bob", remoteIdentityID: "alice")
        let aSend = a.sendKey.withUnsafeBytes { Data($0) }; let aReceive = a.receiveKey.withUnsafeBytes { Data($0) }
        let bSend = b.sendKey.withUnsafeBytes { Data($0) }; let bReceive = b.receiveKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(aSend, bReceive); XCTAssertEqual(aReceive, bSend); XCTAssertNotEqual(aSend, aReceive)
    }

    func testCiphertextContextIsAuthenticated() throws {
        let key = SymmetricKey(size: .bits256)
        let payload = try CryptoEngine.encrypt(Data("ack".utf8), key: key, messageID: "m2", sequence: 7, context: "ack")
        XCTAssertThrowsError(try CryptoEngine.decrypt(payload, key: key, context: "chat"))
    }

    func testReplayWindowAcceptsOutOfOrderOnceAndRejectsDuplicate() {
        var window = ReplayWindow(); XCTAssertTrue(window.accept(10)); XCTAssertTrue(window.accept(12)); XCTAssertTrue(window.accept(11)); XCTAssertFalse(window.accept(11)); XCTAssertFalse(window.accept(0)); XCTAssertFalse(window.accept(1))
    }

    func testBLEAssemblerRejectsOversizedPacket() {
        let assembler = BLEFragmentAssembler(maxPacketBytes: 64)
        XCTAssertNil(assembler.ingest(source: UUID(), packet: Data(repeating: 0xAA, count: 65)))
    }


    func testCiphertextMetadataIsAuthenticated() throws {
        let key = SymmetricKey(size: .bits256)
        let payload = try CryptoEngine.encrypt(Data("secret".utf8), key: key, messageID: UUID().uuidString, sequence: 7)
        let tampered = EncryptedPayload(combined: payload.combined, messageID: payload.messageID, sequence: 8)
        XCTAssertThrowsError(try CryptoEngine.decrypt(tampered, key: key))
    }

    func testPasswordKDFRejectsUnsafeParameters() {
        XCTAssertFalse(PasswordKDF.isSafeParameters(salt: Data(repeating: 1, count: 8), iterations: 100_000, outputByteCount: 32, minimumIterations: 10_000))
        XCTAssertFalse(PasswordKDF.isSafeParameters(salt: Data(repeating: 1, count: 16), iterations: 1, outputByteCount: 32, minimumIterations: 10_000))
        XCTAssertFalse(PasswordKDF.isSafeParameters(salt: Data(repeating: 1, count: 16), iterations: PasswordKDF.maximumAcceptedIterations + 1, outputByteCount: 32, minimumIterations: 10_000))
        XCTAssertTrue(PasswordKDF.isSafeParameters(salt: Data(repeating: 1, count: 16), iterations: 100_000, outputByteCount: 32, minimumIterations: 10_000))
    }

    func testBLEAssemblerHandlesOutOfOrderFragments() {
        let original = Data((0..<2_048).map { UInt8($0 % 253) })
        let fragments = BLEFragment.split(original, maximumPacketSize: 96)
        let assembler = BLEFragmentAssembler()
        let source = UUID()
        var recovered: Data?
        for fragment in fragments.reversed() {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertEqual(recovered, original)
    }

    func testBLEAssemblerSeparatesSameMessageAcrossSources() {
        let original = Data(repeating: 0x3C, count: 512)
        let fragments = BLEFragment.split(original, maximumPacketSize: 80)
        let assembler = BLEFragmentAssembler()
        let sourceA = UUID()
        let sourceB = UUID()
        var recoveredA: Data?
        var recoveredB: Data?
        for fragment in fragments {
            recoveredA = assembler.ingest(source: sourceA, packet: fragment.encoded) ?? recoveredA
            recoveredB = assembler.ingest(source: sourceB, packet: fragment.encoded) ?? recoveredB
        }
        XCTAssertEqual(recoveredA, original)
        XCTAssertEqual(recoveredB, original)
    }

    func testBLEAssemblerRejectsInvalidIndex() {
        let original = Data(repeating: 0x7A, count: 128)
        guard let first = BLEFragment.split(original, maximumPacketSize: 64).first else {
            XCTFail("Expected fragment")
            return
        }
        var packet = first.encoded
        packet[BLEFragment.indexOffset] = 0xFF
        packet[BLEFragment.indexOffset + 1] = 0xFF
        XCTAssertNil(BLEFragmentAssembler().ingest(source: UUID(), packet: packet))
    }

    func testBLEAssemblerRejectsConflictingDuplicate() {
        let original = Data(repeating: 0x22, count: 180)
        let fragments = BLEFragment.split(original, maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler()
        let source = UUID()
        guard var conflicting = fragments.first?.encoded else {
            XCTFail("Expected fragment")
            return
        }
        XCTAssertNil(assembler.ingest(source: source, packet: conflicting))
        conflicting[conflicting.count - 1] ^= 0xFF
        XCTAssertNil(assembler.ingest(source: source, packet: conflicting))
        var recovered: Data?
        for fragment in fragments.dropFirst() {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertNil(recovered)
    }
    func testWireEnvelopeRoundTripAndLengthAuthentication() throws {
        let payload = Data((0..<512).map { UInt8($0 % 251) })
        let encoded = try WireCodec.encodeEnvelope(version: 3, kind: .hello, payload: payload)
        let decoded = try WireCodec.decodeEnvelope(encoded)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.kind, .hello)
        XCTAssertEqual(decoded.payload, payload)

        var truncated = encoded
        truncated.removeLast()
        XCTAssertThrowsError(try WireCodec.decodeEnvelope(truncated))
    }

    func testEncryptedWirePayloadRoundTrip() throws {
        let original = EncryptedPayload(
            combined: Data(repeating: 0xA7, count: 256),
            messageID: UUID().uuidString,
            sequence: 42
        )
        let encoded = try WireCodec.encodeEncryptedPayload(original)
        let decoded = try WireCodec.decodeEncryptedPayload(encoded)
        XCTAssertEqual(decoded.combined, original.combined)
        XCTAssertEqual(decoded.messageID, original.messageID)
        XCTAssertEqual(decoded.sequence, original.sequence)
    }

    func testAttachmentChunkCodecRoundTripAndBounds() throws {
        let clear = Data((0..<49_152).map { UInt8($0 % 251) })
        let chunk = WireAttachmentChunk(index: 7, total: 17, bytes: clear)
        let encoded = try WireCodec.encodeAttachmentChunk(chunk)
        XCTAssertEqual(try WireCodec.decodeAttachmentChunk(encoded), chunk)
        XCTAssertThrowsError(try WireCodec.encodeAttachmentChunk(WireAttachmentChunk(index: 17, total: 17, bytes: clear)))
    }

    func testAttachmentCheckpointCodecRoundTripAndBounds() throws {
        let checkpoint = WireAttachmentCheckpoint(nextIndex: 8, total: 17)
        XCTAssertEqual(try WireCodec.decodeAttachmentCheckpoint(WireCodec.encodeAttachmentCheckpoint(checkpoint)), checkpoint)
        XCTAssertThrowsError(try WireCodec.encodeAttachmentCheckpoint(WireAttachmentCheckpoint(nextIndex: 18, total: 17)))
    }

    func testEncryptedAttachmentChunkFitsBLEFragmentBudget() throws {
        // Protocol 3 sends images as <=48 KiB authenticated chunks instead of one huge envelope.
        let simulatedEncryptedChunk = Data(repeating: 0xCC, count: 49_152 + 64)
        let payload = EncryptedPayload(combined: simulatedEncryptedChunk, messageID: UUID().uuidString, sequence: 1)
        let envelope = try WireCodec.encodeEnvelope(
            version: 3,
            kind: .attachmentChunk,
            payload: WireCodec.encodeEncryptedPayload(payload)
        )
        XCTAssertLessThan(envelope.count, 96_000)
        let fragments = BLEFragment.split(envelope, maximumPacketSize: 180)
        XCTAssertFalse(fragments.isEmpty)
        XCTAssertLessThanOrEqual(fragments.count, BLEFragment.maximumFragmentCount)
    }

    func testBLEFramingSupportsLegacyTwentyByteATTWriteForSmallMessages() {
        let original = Data("hello".utf8)
        let fragments = BLEFragment.split(original, maximumPacketSize: 20)
        XCTAssertFalse(fragments.isEmpty)
        let assembler = BLEFragmentAssembler()
        let source = UUID()
        var recovered: Data?
        for fragment in fragments {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertEqual(recovered, original)
    }

}
