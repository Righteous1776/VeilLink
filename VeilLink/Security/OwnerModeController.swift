import Combine
import CryptoKit
import Foundation

@MainActor
final class OwnerModeController: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var expiresAt: Date?
    @Published private(set) var capabilities: OwnerCapability = []
    @Published var lastError: String?

    // Public half only. Owner Mode never receives universal decryption capability.
    private static let ownerPublicKeyBase64 = "k7p4Oqgqkt4vRSeUDa4TBwYce8u8TSk8wsVeYp0iB2M="
    private var authorizationGeneration = UUID()

    func authorizeLocal(password: String, identity: IdentityManager) -> Bool {
        guard let primaryID = identity.primaryIdentity?.id else {
            lastError = "未找到主身份，无法开启 Owner Mode。"
            return false
        }
        guard identity.verifyPassword(password, for: primaryID) else {
            lastError = "主身份账户密码不正确。"
            return false
        }
        grant(capabilities: .safeDefault, until: Date().addingTimeInterval(20 * 60))
        return true
    }

    func authorize(tokenText: String, deviceID: String) -> Bool {
        guard let data = Data(base64Encoded: tokenText), data.count <= 4_096,
              let token = try? JSONDecoder().decode(OwnerToken.self, from: data),
              token.deviceID == deviceID,
              token.issuedAt <= Date().addingTimeInterval(5 * 60),
              token.expiresAt > Date(),
              token.expiresAt.timeIntervalSince(token.issuedAt) <= 24 * 60 * 60,
              (16...128).contains(token.nonce.utf8.count),
              token.signature.count == 64,
              let ownerPublicKeyData = Data(base64Encoded: Self.ownerPublicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: ownerPublicKeyData),
              publicKey.isValidSignature(token.signature, for: token.signedPayload) else {
            lastError = "授权码无效、已过期或不属于本设备。"
            return false
        }
        let requested = OwnerCapability(rawValue: token.capabilities)
        guard requested.subtracting(.safeDefault).isEmpty else {
            lastError = "授权码包含当前版本不支持的权限。"
            return false
        }
        grant(capabilities: requested, until: token.expiresAt)
        return true
    }

    func isAuthorized(for capability: OwnerCapability) -> Bool {
        refreshExpiration()
        return isUnlocked && capabilities.contains(capability)
    }

    func refreshExpiration() {
        if let expiresAt, expiresAt <= Date() { lock() }
    }

    func lock() {
        authorizationGeneration = UUID()
        capabilities = []
        expiresAt = nil
        isUnlocked = false
    }

    private func grant(capabilities: OwnerCapability, until expiry: Date) {
        authorizationGeneration = UUID()
        let generation = authorizationGeneration
        self.capabilities = capabilities
        expiresAt = expiry
        isUnlocked = true
        lastError = nil
        let delay = max(0, expiry.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.authorizationGeneration == generation else { return }
            self.refreshExpiration()
        }
    }
}

private struct OwnerToken: Codable {
    let deviceID: String
    let capabilities: Int
    let issuedAt: Date
    let expiresAt: Date
    let nonce: String
    let signature: Data

    var signedPayload: Data {
        Data("\(deviceID)|\(capabilities)|\(issuedAt.timeIntervalSince1970)|\(expiresAt.timeIntervalSince1970)|\(nonce)".utf8)
    }
}
