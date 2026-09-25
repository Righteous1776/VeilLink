import CryptoKit
import Foundation
import Security

enum VeilRelayRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case domestic
    case international

    var id: String { rawValue }
    var title: String { self == .domestic ? "国内" : "国际" }
}

enum VeilRelayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case smartDual
    case privacyFirst
    case domesticOnly
    case internationalOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartDual: return "智能双通道"
        case .privacyFirst: return "隐私优先"
        case .domesticOnly: return "仅国内"
        case .internationalOnly: return "仅国际"
        }
    }
}

struct VeilRelayProviderConfiguration: Codable, Hashable, Identifiable, Sendable {
    let region: VeilRelayRegion
    var baseURL: URL?
    var enabled: Bool

    var id: String { region.rawValue }
}

struct VeilRelayRouteDescriptor: Equatable, Sendable {
    let mailboxID: String
    let readToken: String
    let writeToken: String
    let epoch: Int64
}

struct VeilRelayClearFrame: Codable, Equatable, Sendable {
    let version: UInt8
    let deliveryID: String
    let sentAt: Date
    let wireEnvelope: Data
    let padding: Data
}

struct VeilRelayPushRequest: Codable, Sendable {
    let version: UInt8
    let packetID: String
    let mailbox: String
    let writeToken: String
    let expiresAt: Date
    let body: Data
}

struct VeilRelayRegisterRequest: Codable, Sendable {
    let version: UInt8
    let mailbox: String
    let readToken: String
    let writeToken: String
    let expiresAt: Date
}

struct VeilRelayStoredPacket: Codable, Sendable {
    let packetID: String
    let body: Data
    let expiresAt: Date
    let receivedAt: Date?
}

struct VeilRelayPullResponse: Codable, Sendable {
    let version: UInt8
    let packets: [VeilRelayStoredPacket]
}

struct VeilRelayAckRequest: Codable, Sendable {
    let version: UInt8
    let mailbox: String
    let readToken: String
    let packetIDs: [String]
}

enum VeilRelayCryptoError: Error {
    case invalidSecret
    case invalidFrame
    case invalidRoute
}

enum VeilRelayCrypto {
    static let protocolVersion: UInt8 = 1
    static let epochSeconds: TimeInterval = 7 * 24 * 60 * 60
    static let maximumWireEnvelopeBytes = 100 * 1024
    static let maximumStoredBodyBytes = 160 * 1024

    static func epoch(for date: Date = Date()) -> Int64 {
        Int64(floor(date.timeIntervalSince1970 / epochSeconds))
    }

    static func inboundEpochs(for date: Date = Date()) -> [Int64] {
        let current = epoch(for: date)
        return [current, current - 1]
    }

    static func route(
        pairSecret: Data,
        senderIdentityID: String,
        receiverIdentityID: String,
        provider: VeilRelayRegion,
        epoch: Int64
    ) throws -> VeilRelayRouteDescriptor {
        guard pairSecret.count == 32,
              !senderIdentityID.isEmpty,
              !receiverIdentityID.isEmpty,
              senderIdentityID != receiverIdentityID else { throw VeilRelayCryptoError.invalidSecret }

        let context = "\(provider.rawValue)|\(senderIdentityID)|\(receiverIdentityID)|\(epoch)"
        return VeilRelayRouteDescriptor(
            mailboxID: token(pairSecret, label: "mailbox|\(context)", bytes: 24),
            readToken: token(pairSecret, label: "read|\(context)", bytes: 32),
            writeToken: token(pairSecret, label: "write|\(context)", bytes: 32),
            epoch: epoch
        )
    }

    static func seal(
        wireEnvelope: Data,
        deliveryID: String,
        pairSecret: Data,
        senderIdentityID: String,
        receiverIdentityID: String,
        provider: VeilRelayRegion,
        epoch: Int64,
        sentAt: Date = Date()
    ) throws -> Data {
        guard !wireEnvelope.isEmpty, wireEnvelope.count <= maximumWireEnvelopeBytes,
              UUID(uuidString: deliveryID) != nil else { throw VeilRelayCryptoError.invalidFrame }
        let target = paddedTargetSize(for: wireEnvelope.count)
        let clearWithoutPadding = VeilRelayClearFrame(
            version: protocolVersion,
            deliveryID: deliveryID,
            sentAt: sentAt,
            wireEnvelope: wireEnvelope,
            padding: Data()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let base = try encoder.encode(clearWithoutPadding)
        let paddingCount = max(0, target - base.count)
        let frame = VeilRelayClearFrame(
            version: protocolVersion,
            deliveryID: deliveryID,
            sentAt: sentAt,
            wireEnvelope: wireEnvelope,
            padding: randomData(count: paddingCount)
        )
        let clear = try encoder.encode(frame)
        let key = try directionalKey(
            pairSecret: pairSecret,
            senderIdentityID: senderIdentityID,
            receiverIdentityID: receiverIdentityID,
            provider: provider,
            epoch: epoch
        )
        let aad = Data("VeilLink/InternetRelay/v1|\(provider.rawValue)|\(epoch)".utf8)
        let sealed = try ChaChaPoly.seal(clear, using: key, authenticating: aad).combined
        guard sealed.count <= maximumStoredBodyBytes else { throw VeilRelayCryptoError.invalidFrame }
        return sealed
    }

    static func open(
        body: Data,
        pairSecret: Data,
        senderIdentityID: String,
        receiverIdentityID: String,
        provider: VeilRelayRegion,
        epoch: Int64
    ) throws -> VeilRelayClearFrame {
        guard !body.isEmpty, body.count <= maximumStoredBodyBytes else { throw VeilRelayCryptoError.invalidFrame }
        let key = try directionalKey(
            pairSecret: pairSecret,
            senderIdentityID: senderIdentityID,
            receiverIdentityID: receiverIdentityID,
            provider: provider,
            epoch: epoch
        )
        let aad = Data("VeilLink/InternetRelay/v1|\(provider.rawValue)|\(epoch)".utf8)
        let clear = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: body), using: key, authenticating: aad)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let frame = try decoder.decode(VeilRelayClearFrame.self, from: clear)
        guard frame.version == protocolVersion,
              UUID(uuidString: frame.deliveryID) != nil,
              !frame.wireEnvelope.isEmpty,
              frame.wireEnvelope.count <= maximumWireEnvelopeBytes,
              abs(frame.sentAt.timeIntervalSinceNow) <= 8 * 24 * 60 * 60 else {
            throw VeilRelayCryptoError.invalidFrame
        }
        return frame
    }

    static func transportID(pairSecret: Data, localIdentityID: String, peerIdentityID: String) -> UUID? {
        guard pairSecret.count == 32 else { return nil }
        let ordered = [localIdentityID, peerIdentityID].sorted().joined(separator: "|")
        let bytes = Array(HMAC<SHA256>.authenticationCode(
            for: Data("VeilLink/RelayTransport/v1|\(ordered)".utf8),
            using: SymmetricKey(data: pairSecret)
        ).prefix(16))
        guard bytes.count == 16 else { return nil }
        var tuple: uuid_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        withUnsafeMutableBytes(of: &tuple) { raw in
            for index in 0..<16 { raw[index] = bytes[index] }
        }
        return UUID(uuid: tuple)
    }

    private static func directionalKey(
        pairSecret: Data,
        senderIdentityID: String,
        receiverIdentityID: String,
        provider: VeilRelayRegion,
        epoch: Int64
    ) throws -> SymmetricKey {
        guard pairSecret.count == 32 else { throw VeilRelayCryptoError.invalidSecret }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: pairSecret),
            salt: Data("VeilLink/RelayEpoch/v1|\(epoch)".utf8),
            info: Data("outer|\(provider.rawValue)|\(senderIdentityID)|\(receiverIdentityID)".utf8),
            outputByteCount: 32
        )
    }

    private static func token(_ pairSecret: Data, label: String, bytes: Int) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data("VeilLink/Relay/v1|\(label)".utf8), using: SymmetricKey(data: pairSecret))
        return Data(mac.prefix(bytes)).base64URLEncodedString()
    }

    private static func paddedTargetSize(for wireBytes: Int) -> Int {
        let candidates = [768, 1536, 4096, 8192, 16384, 32768, 65536, 114688]
        let estimatedJSONOverhead = 320
        let desired = wireBytes + estimatedJSONOverhead
        return candidates.first(where: { $0 >= desired }) ?? 114688
    }

    private static func randomData(count: Int) -> Data {
        guard count > 0 else { return Data() }
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
