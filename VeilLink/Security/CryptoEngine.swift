import CryptoKit
import Foundation

enum CryptoEngineError: Error {
    case invalidCiphertext
    case invalidSignature
    case invalidKeyMaterial
}

struct EphemeralKeyPair {
    let privateKey: Curve25519.KeyAgreement.PrivateKey
    var publicKey: Data { privateKey.publicKey.rawRepresentation }
}

struct SessionKeyMaterial {
    let rootKey: SymmetricKey
    let sendKey: SymmetricKey
    let receiveKey: SymmetricKey
}

struct EncryptedPayload: Codable {
    let combined: Data
    let messageID: String
    let sequence: UInt64
}

enum CryptoEngine {
    static func newIdentityKey() -> Curve25519.Signing.PrivateKey { Curve25519.Signing.PrivateKey() }

    static func identityID(publicKey: Data) -> String {
        let digest = Data(SHA256.hash(data: publicKey)).prefix(16)
        let encoded = Base32.encode(Data(digest))
        return stride(from: 0, to: encoded.count, by: 4).map { offset -> String in
            let start = encoded.index(encoded.startIndex, offsetBy: offset)
            let end = encoded.index(start, offsetBy: min(4, encoded.distance(from: start, to: encoded.endIndex)))
            return String(encoded[start..<end])
        }.joined(separator: "-")
    }

    static func newEphemeralKey() -> EphemeralKeyPair { EphemeralKeyPair(privateKey: Curve25519.KeyAgreement.PrivateKey()) }
    static func sign(_ data: Data, with key: Curve25519.Signing.PrivateKey) throws -> Data { try key.signature(for: data) }

    static func verify(signature: Data, for data: Data, publicKey: Data) throws {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(signature, for: data) else { throw CryptoEngineError.invalidSignature }
    }

    static func deriveSessionRootKey(localPrivateKey: Curve25519.KeyAgreement.PrivateKey, remotePublicKey: Data, transcript: Data) throws -> SymmetricKey {
        let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remotePublicKey)
        let shared = try localPrivateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(SHA256.hash(data: transcript)), sharedInfo: Data("VeilLink/SessionRoot/v4".utf8), outputByteCount: 32)
    }

    static func deriveSessionKeys(localPrivateKey: Curve25519.KeyAgreement.PrivateKey, remotePublicKey: Data, transcript: Data, localIdentityID: String, remoteIdentityID: String) throws -> SessionKeyMaterial {
        guard localIdentityID != remoteIdentityID else { throw CryptoEngineError.invalidKeyMaterial }
        let rootKey = try deriveSessionRootKey(localPrivateKey: localPrivateKey, remotePublicKey: remotePublicKey, transcript: transcript)
        return SessionKeyMaterial(
            rootKey: rootKey,
            sendKey: directionalKey(rootKey: rootKey, senderIdentityID: localIdentityID, receiverIdentityID: remoteIdentityID),
            receiveKey: directionalKey(rootKey: rootKey, senderIdentityID: remoteIdentityID, receiverIdentityID: localIdentityID)
        )
    }

    static func deriveSessionKey(localPrivateKey: Curve25519.KeyAgreement.PrivateKey, remotePublicKey: Data, transcript: Data) throws -> SymmetricKey {
        try deriveSessionRootKey(localPrivateKey: localPrivateKey, remotePublicKey: remotePublicKey, transcript: transcript)
    }

    static func pairingCode(key: SymmetricKey, transcript: Data) -> String {
        let code = HMAC<SHA256>.authenticationCode(for: transcript, using: key)
        let value = code.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return String(format: "%06u", value % 1_000_000)
    }

    static func encrypt(_ plaintext: Data, key: SymmetricKey, messageID: String, sequence: UInt64, context: String = "chat") throws -> EncryptedPayload {
        guard sequence > 0 else { throw CryptoEngineError.invalidCiphertext }
        let sealed = try ChaChaPoly.seal(plaintext, using: key, authenticating: authenticatedHeader(messageID: messageID, sequence: sequence, context: context))
        return EncryptedPayload(combined: sealed.combined, messageID: messageID, sequence: sequence)
    }

    static func decrypt(_ payload: EncryptedPayload, key: SymmetricKey, context: String = "chat") throws -> Data {
        guard payload.sequence > 0 else { throw CryptoEngineError.invalidCiphertext }
        let box = try ChaChaPoly.SealedBox(combined: payload.combined)
        return try ChaChaPoly.open(box, using: key, authenticating: authenticatedHeader(messageID: payload.messageID, sequence: payload.sequence, context: context))
    }

    private static func directionalKey(rootKey: SymmetricKey, senderIdentityID: String, receiverIdentityID: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: rootKey, salt: Data(), info: Data("VeilLink/Direction/v4|\(senderIdentityID)|\(receiverIdentityID)".utf8), outputByteCount: 32)
    }

    private static func authenticatedHeader(messageID: String, sequence: UInt64, context: String) -> Data {
        Data("VeilLink/AAD/v4|\(context)|\(messageID)|\(sequence)".utf8)
    }
}
