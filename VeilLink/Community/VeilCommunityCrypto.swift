import CryptoKit
import Foundation

enum VeilCommunityRoomKind: String, Codable, CaseIterable, Sendable {
    case privateGroup
    case publicChannel
}

enum VeilCommunityIdentityMode: String, Codable, CaseIterable, Sendable {
    case identified
    case anonymous
}

struct VeilCommunityRoom: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    let kind: VeilCommunityRoomKind
    let createdAt: Date
    let ownerIdentityID: String?
    let authorityPublicKey: Data
    var epoch: UInt32
    var defaultHopLimit: UInt8
    var isDiscoverable: Bool
}

struct VeilCommunityMessageCleartext: Codable, Equatable, Sendable {
    let messageID: UUID
    let roomID: UUID
    let sentAt: Date
    let body: String
    let senderMode: VeilCommunityIdentityMode
    let senderAlias: String
    let senderIdentityID: String?
    let senderPublicKey: Data
    let signature: Data
}

struct VeilCommunitySealedMessage: Codable, Equatable, Sendable {
    let version: UInt8
    let roomID: UUID
    let epoch: UInt32
    let messageID: UUID
    let combined: Data
}

enum VeilCommunityCryptoError: Error, Equatable {
    case invalidRoomKey
    case invalidMessage
    case invalidSignature
    case wrongRoom
}

enum VeilCommunityCrypto {
    private static let version: UInt8 = 1
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    static let maximumMessageBytes = 12 * 1_024

    static func generateRoomKey() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) })
    }

    static func anonymousSigningKey() -> Curve25519.Signing.PrivateKey {
        Curve25519.Signing.PrivateKey()
    }

    static func makeAlias(publicKey: Data, roomID: UUID) -> String {
        var data = Data("VeilLink/CommunityAlias/v1|\(roomID.uuidString)|".utf8)
        data.append(publicKey)
        let digest = SHA256.hash(data: data)
        let value = Data(digest).prefix(5).map { String(format: "%02X", $0) }.joined()
        return "ANON-\(value)"
    }

    static func seal(
        body: String,
        room: VeilCommunityRoom,
        roomKey: Data,
        senderMode: VeilCommunityIdentityMode,
        realIdentityID: String?,
        signingKey: Curve25519.Signing.PrivateKey,
        sentAt: Date = Date()
    ) throws -> VeilCommunitySealedMessage {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.lengthOfBytes(using: .utf8) <= maximumMessageBytes,
              roomKey.count == 32 else { throw VeilCommunityCryptoError.invalidMessage }

        let messageID = UUID()
        let publicKey = signingKey.publicKey.rawRepresentation
        let alias: String
        let identityID: String?
        switch senderMode {
        case .identified:
            guard let realIdentityID, !realIdentityID.isEmpty else { throw VeilCommunityCryptoError.invalidMessage }
            alias = realIdentityID
            identityID = realIdentityID
        case .anonymous:
            alias = makeAlias(publicKey: publicKey, roomID: room.id)
            identityID = nil
        }

        let unsigned = signaturePayload(
            messageID: messageID,
            roomID: room.id,
            sentAt: sentAt,
            body: trimmed,
            senderMode: senderMode,
            senderAlias: alias,
            senderIdentityID: identityID,
            senderPublicKey: publicKey
        )
        let signature = try signingKey.signature(for: unsigned)
        let clear = VeilCommunityMessageCleartext(
            messageID: messageID,
            roomID: room.id,
            sentAt: sentAt,
            body: trimmed,
            senderMode: senderMode,
            senderAlias: alias,
            senderIdentityID: identityID,
            senderPublicKey: publicKey,
            signature: signature
        )
        let encoded = try encoder.encode(clear)
        let key = SymmetricKey(data: roomKey)
        let aad = associatedData(roomID: room.id, epoch: room.epoch, messageID: messageID)
        let sealed = try ChaChaPoly.seal(encoded, using: key, authenticating: aad)
        return VeilCommunitySealedMessage(
            version: version,
            roomID: room.id,
            epoch: room.epoch,
            messageID: messageID,
            combined: sealed.combined
        )
    }

    static func open(_ sealed: VeilCommunitySealedMessage, room: VeilCommunityRoom, roomKey: Data) throws -> VeilCommunityMessageCleartext {
        guard sealed.version == version,
              sealed.roomID == room.id,
              sealed.epoch == room.epoch,
              roomKey.count == 32,
              sealed.combined.count <= maximumMessageBytes + 2_048 else {
            throw VeilCommunityCryptoError.wrongRoom
        }
        let key = SymmetricKey(data: roomKey)
        let aad = associatedData(roomID: sealed.roomID, epoch: sealed.epoch, messageID: sealed.messageID)
        let clearData = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: sealed.combined), using: key, authenticating: aad)
        let clear = try decoder.decode(VeilCommunityMessageCleartext.self, from: clearData)
        guard clear.messageID == sealed.messageID,
              clear.roomID == room.id,
              clear.senderPublicKey.count == 32,
              clear.signature.count == 64,
              !clear.body.isEmpty,
              clear.body.lengthOfBytes(using: .utf8) <= maximumMessageBytes,
              abs(clear.sentAt.timeIntervalSinceNow) <= 7 * 24 * 60 * 60 else {
            throw VeilCommunityCryptoError.invalidMessage
        }
        let unsigned = signaturePayload(
            messageID: clear.messageID,
            roomID: clear.roomID,
            sentAt: clear.sentAt,
            body: clear.body,
            senderMode: clear.senderMode,
            senderAlias: clear.senderAlias,
            senderIdentityID: clear.senderIdentityID,
            senderPublicKey: clear.senderPublicKey
        )
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: clear.senderPublicKey)
        guard publicKey.isValidSignature(clear.signature, for: unsigned) else {
            throw VeilCommunityCryptoError.invalidSignature
        }
        if clear.senderMode == .anonymous {
            guard clear.senderIdentityID == nil,
                  clear.senderAlias == makeAlias(publicKey: clear.senderPublicKey, roomID: room.id) else {
                throw VeilCommunityCryptoError.invalidMessage
            }
        } else {
            guard let identity = clear.senderIdentityID,
                  identity == CryptoEngine.identityID(publicKey: clear.senderPublicKey),
                  clear.senderAlias == identity else {
                throw VeilCommunityCryptoError.invalidMessage
            }
        }
        return clear
    }

    private static func signaturePayload(
        messageID: UUID,
        roomID: UUID,
        sentAt: Date,
        body: String,
        senderMode: VeilCommunityIdentityMode,
        senderAlias: String,
        senderIdentityID: String?,
        senderPublicKey: Data
    ) -> Data {
        var data = Data("VeilLink/CommunityMessage/v1|\(messageID.uuidString)|\(roomID.uuidString)|\(Int64(sentAt.timeIntervalSince1970 * 1000))|\(senderMode.rawValue)|\(senderAlias)|\(senderIdentityID ?? "-")|".utf8)
        data.append(senderPublicKey)
        data.append(0)
        data.append(Data(body.utf8))
        return data
    }

    private static func associatedData(roomID: UUID, epoch: UInt32, messageID: UUID) -> Data {
        Data("VeilLink/CommunityAAD/v1|\(roomID.uuidString)|\(epoch)|\(messageID.uuidString)".utf8)
    }
}
