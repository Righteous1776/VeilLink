#if os(iOS)
import Foundation
import CryptoKit
import Security

/// Both signed targets must have the SAME App Group and keychain-access-group entitlements.
/// No implicit fallback to unencrypted pixels if entitlements are missing.
struct VeilScreenBroadcastSecurityConfig {
    let appGroupID: String
    let keychainAccessGroup: String

    static func load() -> Self? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "VeilScreenAppGroup") as? String,
              let keychain = Bundle.main.object(forInfoDictionaryKey: "VeilScreenKeychainGroup") as? String,
              group.hasPrefix("group."), !keychain.isEmpty,
              !group.contains("$("), !keychain.contains("$(") else { return nil }
        return Self(appGroupID: group, keychainAccessGroup: keychain)
    }
}

struct VeilScreenSharedKeyStore {
    let config: VeilScreenBroadcastSecurityConfig
    private let service = "studio.zeo.veillink.veilscreen.broadcast.v2"

    func setNewKey(sessionID: UUID) throws {
        let bytes = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: config.keychainAccessGroup,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionID.uuidString,
            kSecValueData as String: bytes,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var query = attributes
        query.removeValue(forKey: kSecValueData as String)
        query.removeValue(forKey: kSecAttrAccessible as String)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw VeilScreenBroadcastError.keychain(status) }
    }

    func fetch(sessionID: UUID) -> SymmetricKey? {
        let request: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: config.keychainAccessGroup,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let bytes = result as? Data, bytes.count == 32 else { return nil }
        return SymmetricKey(data: bytes)
    }

    func remove(sessionID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: config.keychainAccessGroup,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum VeilScreenBroadcastError: Error {
    case missingEntitlements
    case missingKey
    case malformedFrame
    case frameTooLarge
    case appGroupUnavailable
    case keychain(OSStatus)
}

/// Session config does not contain screen content or the encryption key.
struct VeilScreenBroadcastSessionConfig: Codable {
    let sessionID: UUID
    let expiresAt: Date
    let frameIntervalSeconds: Double
    let targetWidth: Int
    let byteBudget: Int

    func valid(at date: Date) -> Bool {
        expiresAt > date && expiresAt.timeIntervalSince(date) <= 1800 &&
        (0.5...20).contains(frameIntervalSeconds) &&
        (128...1024).contains(targetWidth) &&
        (512...32768).contains(byteBudget)
    }
}
#endif
