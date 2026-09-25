import CryptoKit
import Foundation
import Security

struct VeilRemotePairQRCode: Codable, Equatable, Sendable {
    let version: UInt8
    let offerID: String
    let offerSecret: Data
    let initiatorEphemeralPublicKey: Data
    let createdAt: Date
    let expiresAt: Date
}

enum VeilRemotePairRole: String, Codable, Sendable {
    case initiator
    case responder
}

enum VeilRemotePairRelayDirection: String, Codable, Sendable {
    case toInitiator
    case toResponder
}

enum VeilRemotePairPacketKind: UInt8, Codable, Sendable {
    case claim = 1
    case accept = 2
    case confirm = 3
    case reject = 4
}

struct VeilRemotePairRelayPacket: Codable, Sendable {
    let version: UInt8
    let kind: VeilRemotePairPacketKind
    let logicalPacketID: String
    let offerID: String
    let claimID: String
    let responderEphemeralPublicKey: Data?
    let innerCiphertext: Data
    let sentAt: Date
}

struct VeilRemotePairIdentityProof: Codable, Equatable, Sendable {
    let identityID: String
    let identityPublicKey: Data
    let displayName: String
    let nonce: Data
    let signature: Data
}

struct VeilRemotePairConfirmation: Codable, Equatable, Sendable {
    let version: UInt8
    let offerID: String
    let claimID: String
    let identityID: String
    let confirmedAt: Date
}

struct VeilRemotePairRoute: Equatable, Sendable {
    let mailbox: String
    let readToken: String
    let writeToken: String
}

struct VeilRemotePairCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let role: VeilRemotePairRole
    let peerIdentityID: String
    let peerDisplayName: String
    let peerPublicKey: Data
    let sas: String
    let expiresAt: Date
    var localConfirmed: Bool
    var remoteConfirmed: Bool

    var fingerprint: String {
        peerIdentityID.split(separator: "-").prefix(3).joined(separator: "-")
    }
}

enum VeilRemotePairError: LocalizedError {
    case invalidQRCode
    case expiredQRCode
    case noRelayEndpoint
    case invalidPacket
    case invalidIdentityProof
    case selfPairing
    case handshakeExpired

    var errorDescription: String? {
        switch self {
        case .invalidQRCode: return "这不是有效的 VeilLink 配对二维码。"
        case .expiredQRCode: return "配对二维码已经超过 60 秒有效期，请让对方刷新二维码。"
        case .noRelayEndpoint: return "至少需要配置一个可用的国内或国际 Relay Endpoint。"
        case .invalidPacket: return "远程配对数据校验失败。"
        case .invalidIdentityProof: return "无法验证对方的 VeilLink 身份签名。"
        case .selfPairing: return "不能与当前身份自身配对。"
        case .handshakeExpired: return "远程配对会话已经过期。"
        }
    }
}

enum VeilRemotePairCrypto {
    static let version: UInt8 = 1
    static let qrLifetime: TimeInterval = 60
    static let handshakeGrace: TimeInterval = 120
    static let maximumPacketBytes = 24 * 1024

    static func makeQRCode(ephemeralPublicKey: Data, now: Date = Date()) throws -> VeilRemotePairQRCode {
        guard ephemeralPublicKey.count == 32 else { throw VeilRemotePairError.invalidQRCode }
        let secret = randomData(count: 32)
        guard secret.count == 32 else { throw VeilRemotePairError.invalidQRCode }
        return VeilRemotePairQRCode(
            version: version,
            offerID: UUID().uuidString,
            offerSecret: secret,
            initiatorEphemeralPublicKey: ephemeralPublicKey,
            createdAt: now,
            expiresAt: now.addingTimeInterval(qrLifetime)
        )
    }

    static func validate(_ qr: VeilRemotePairQRCode, now: Date = Date()) throws {
        guard qr.version == version,
              UUID(uuidString: qr.offerID) != nil,
              qr.offerSecret.count == 32,
              qr.initiatorEphemeralPublicKey.count == 32,
              qr.expiresAt > qr.createdAt,
              qr.expiresAt.timeIntervalSince(qr.createdAt) <= qrLifetime + 2,
              qr.createdAt.timeIntervalSince(now) < 10 else {
            throw VeilRemotePairError.invalidQRCode
        }
        guard now <= qr.expiresAt else { throw VeilRemotePairError.expiredQRCode }
    }

    static func route(qr: VeilRemotePairQRCode, region: VeilRelayRegion, direction: VeilRemotePairRelayDirection) throws -> VeilRemotePairRoute {
        try validateStructure(qr)
        let context = "\(region.rawValue)|\(direction.rawValue)|\(qr.offerID)"
        return VeilRemotePairRoute(
            mailbox: token(secret: qr.offerSecret, label: "mailbox|\(context)", bytes: 24),
            readToken: token(secret: qr.offerSecret, label: "read|\(context)", bytes: 32),
            writeToken: token(secret: qr.offerSecret, label: "write|\(context)", bytes: 32)
        )
    }

    static func bootstrapKey(
        localEphemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        remoteEphemeralPublicKey: Data,
        qr: VeilRemotePairQRCode
    ) throws -> SymmetricKey {
        try validateStructure(qr)
        let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralPublicKey)
        let shared = try localEphemeralPrivateKey.sharedSecretFromKeyAgreement(with: remote)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: qr.offerSecret,
            sharedInfo: Data("VeilLink/RemotePair/Bootstrap/v1|\(qr.offerID)".utf8),
            outputByteCount: 32
        )
    }

    static func finalPairSecret(
        localEphemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        remoteEphemeralPublicKey: Data,
        qr: VeilRemotePairQRCode,
        initiatorIdentityID: String,
        responderIdentityID: String,
        initiatorPublicKey: Data,
        responderPublicKey: Data
    ) throws -> Data {
        let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralPublicKey)
        let shared = try localEphemeralPrivateKey.sharedSecretFromKeyAgreement(with: remote)
        let orderedIDs = [initiatorIdentityID, responderIdentityID]
        var info = Data("VeilLink/RemotePair/PairSecret/v1|\(qr.offerID)|\(orderedIDs[0])|\(orderedIDs[1])".utf8)
        appendLengthPrefixed(initiatorPublicKey, to: &info)
        appendLengthPrefixed(responderPublicKey, to: &info)
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: qr.offerSecret, sharedInfo: info, outputByteCount: 32)
        return keyData(key)
    }

    static func sas(pairSecret: Data, offerID: String, initiatorIdentityID: String, responderIdentityID: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data("VeilLink/RemotePair/SAS/v1|\(offerID)|\(initiatorIdentityID)|\(responderIdentityID)".utf8),
            using: SymmetricKey(data: pairSecret)
        )
        let value = mac.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return String(format: "%06u", value % 1_000_000)
    }

    static func makeIdentityProof(
        identity: LocalIdentity,
        signingKey: Curve25519.Signing.PrivateKey,
        qr: VeilRemotePairQRCode,
        claimID: String,
        initiatorEphemeralPublicKey: Data,
        responderEphemeralPublicKey: Data,
        role: VeilRemotePairRole,
        nonce: Data
    ) throws -> VeilRemotePairIdentityProof {
        guard nonce.count >= 16 && nonce.count <= 64 else { throw VeilRemotePairError.invalidPacket }
        let signable = identityProofSignable(
            identityID: identity.id,
            identityPublicKey: identity.publicKey,
            displayName: identity.displayName,
            qr: qr,
            claimID: claimID,
            initiatorEphemeralPublicKey: initiatorEphemeralPublicKey,
            responderEphemeralPublicKey: responderEphemeralPublicKey,
            role: role,
            nonce: nonce
        )
        return VeilRemotePairIdentityProof(
            identityID: identity.id,
            identityPublicKey: identity.publicKey,
            displayName: identity.displayName,
            nonce: nonce,
            signature: try CryptoEngine.sign(signable, with: signingKey)
        )
    }

    static func verifyIdentityProof(
        _ proof: VeilRemotePairIdentityProof,
        qr: VeilRemotePairQRCode,
        claimID: String,
        initiatorEphemeralPublicKey: Data,
        responderEphemeralPublicKey: Data,
        role: VeilRemotePairRole
    ) throws {
        guard proof.identityPublicKey.count == 32,
              proof.identityID == CryptoEngine.identityID(publicKey: proof.identityPublicKey),
              !proof.displayName.isEmpty,
              proof.displayName.lengthOfBytes(using: .utf8) <= 64,
              proof.nonce.count >= 16,
              proof.nonce.count <= 64 else { throw VeilRemotePairError.invalidIdentityProof }
        let signable = identityProofSignable(
            identityID: proof.identityID,
            identityPublicKey: proof.identityPublicKey,
            displayName: proof.displayName,
            qr: qr,
            claimID: claimID,
            initiatorEphemeralPublicKey: initiatorEphemeralPublicKey,
            responderEphemeralPublicKey: responderEphemeralPublicKey,
            role: role,
            nonce: proof.nonce
        )
        do {
            try CryptoEngine.verify(signature: proof.signature, for: signable, publicKey: proof.identityPublicKey)
        } catch {
            throw VeilRemotePairError.invalidIdentityProof
        }
    }

    static func sealInner<T: Encodable>(_ value: T, key: SymmetricKey, qr: VeilRemotePairQRCode, claimID: String, kind: VeilRemotePairPacketKind) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let clear = try encoder.encode(value)
        let aad = Data("VeilLink/RemotePair/Inner/v1|\(qr.offerID)|\(claimID)|\(kind.rawValue)".utf8)
        return try ChaChaPoly.seal(clear, using: key, authenticating: aad).combined
    }

    static func openInner<T: Decodable>(_ type: T.Type, ciphertext: Data, key: SymmetricKey, qr: VeilRemotePairQRCode, claimID: String, kind: VeilRemotePairPacketKind) throws -> T {
        guard ciphertext.count <= maximumPacketBytes else { throw VeilRemotePairError.invalidPacket }
        let aad = Data("VeilLink/RemotePair/Inner/v1|\(qr.offerID)|\(claimID)|\(kind.rawValue)".utf8)
        let clear = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: ciphertext), using: key, authenticating: aad)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: clear)
    }

    static func sealRelayPacket(_ packet: VeilRemotePairRelayPacket, qr: VeilRemotePairQRCode, region: VeilRelayRegion, direction: VeilRemotePairRelayDirection) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let clear = try encoder.encode(packet)
        guard clear.count <= maximumPacketBytes else { throw VeilRemotePairError.invalidPacket }
        let key = outerKey(qr: qr, region: region, direction: direction)
        let aad = Data("VeilLink/RemotePair/Outer/v1|\(region.rawValue)|\(direction.rawValue)|\(qr.offerID)".utf8)
        return try ChaChaPoly.seal(clear, using: key, authenticating: aad).combined
    }

    static func openRelayPacket(_ body: Data, qr: VeilRemotePairQRCode, region: VeilRelayRegion, direction: VeilRemotePairRelayDirection) throws -> VeilRemotePairRelayPacket {
        guard body.count <= maximumPacketBytes + 128 else { throw VeilRemotePairError.invalidPacket }
        let key = outerKey(qr: qr, region: region, direction: direction)
        let aad = Data("VeilLink/RemotePair/Outer/v1|\(region.rawValue)|\(direction.rawValue)|\(qr.offerID)".utf8)
        let clear = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: body), using: key, authenticating: aad)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let packet = try decoder.decode(VeilRemotePairRelayPacket.self, from: clear)
        guard packet.version == version,
              UUID(uuidString: packet.logicalPacketID) != nil,
              packet.offerID == qr.offerID,
              UUID(uuidString: packet.claimID) != nil,
              abs(packet.sentAt.timeIntervalSinceNow) <= qrLifetime + handshakeGrace else {
            throw VeilRemotePairError.invalidPacket
        }
        return packet
    }

    private static func identityProofSignable(
        identityID: String,
        identityPublicKey: Data,
        displayName: String,
        qr: VeilRemotePairQRCode,
        claimID: String,
        initiatorEphemeralPublicKey: Data,
        responderEphemeralPublicKey: Data,
        role: VeilRemotePairRole,
        nonce: Data
    ) -> Data {
        var data = Data("VeilLink/RemotePair/IdentityProof/v1|\(role.rawValue)|\(qr.offerID)|\(claimID)|\(identityID)".utf8)
        appendLengthPrefixed(identityPublicKey, to: &data)
        appendLengthPrefixed(Data(displayName.utf8), to: &data)
        appendLengthPrefixed(initiatorEphemeralPublicKey, to: &data)
        appendLengthPrefixed(responderEphemeralPublicKey, to: &data)
        appendLengthPrefixed(nonce, to: &data)
        return data
    }

    private static func outerKey(qr: VeilRemotePairQRCode, region: VeilRelayRegion, direction: VeilRemotePairRelayDirection) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: qr.offerSecret),
            salt: Data("VeilLink/RemotePair/OuterSalt/v1".utf8),
            info: Data("\(region.rawValue)|\(direction.rawValue)|\(qr.offerID)".utf8),
            outputByteCount: 32
        )
    }

    private static func token(secret: Data, label: String, bytes: Int) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data("VeilLink/RemotePair/v1|\(label)".utf8), using: SymmetricKey(data: secret))
        return Data(mac.prefix(bytes)).base64URLEncodedString()
    }

    private static func validateStructure(_ qr: VeilRemotePairQRCode) throws {
        guard qr.version == version,
              qr.offerSecret.count == 32,
              qr.initiatorEphemeralPublicKey.count == 32,
              UUID(uuidString: qr.offerID) != nil else { throw VeilRemotePairError.invalidQRCode }
    }

    private static func appendLengthPrefixed(_ value: Data, to output: inout Data) {
        var length = UInt32(value.count).bigEndian
        withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }
        output.append(value)
    }

    private static func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    private static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { return Data() }
        return Data(bytes)
    }
}

enum VeilRemotePairQRCodeCodec {
    private static let prefix = "veillink://pair?v=1&d="

    static func encode(_ qr: VeilRemotePairQRCode) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return prefix + try encoder.encode(qr).base64URLEncodedString()
    }

    static func decode(_ text: String, now: Date = Date()) throws -> VeilRemotePairQRCode {
        guard text.hasPrefix(prefix),
              let data = Data(base64URLString: String(text.dropFirst(prefix.count))) else {
            throw VeilRemotePairError.invalidQRCode
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let qr = try decoder.decode(VeilRemotePairQRCode.self, from: data)
        try VeilRemotePairCrypto.validate(qr, now: now)
        return qr
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLString: String) {
        var value = base64URLString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder > 0 { value += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: value)
    }
}
