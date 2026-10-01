import Foundation
import Security

enum KeychainError: LocalizedError {
    case temporarilyUnavailable(OSStatus)
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        let status: OSStatus
        switch self {
        case .temporarilyUnavailable(let value), .unexpectedStatus(let value): status = value
        }
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        switch self {
        case .temporarilyUnavailable:
            return "Keychain 当前暂不可读取：\(detail)"
        case .unexpectedStatus:
            return "Keychain 读取失败：\(detail)"
        }
    }
}

final class KeychainStore {
    private let service: String

    init(service: String = "studio.zeo.veillink") {
        self.service = service
    }

    func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.unexpectedStatus(updateStatus) }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    static func isTransientReadStatus(_ status: OSStatus) -> Bool {
        status == errSecInteractionNotAllowed || status == errSecNotAvailable
    }

    /// Distinguishes "item genuinely missing" from "Keychain cannot be read right now".
    /// Callers that protect irreplaceable state (database keys) must use this throwing API.
    func readData(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedStatus(errSecDecode) }
            return data
        case errSecItemNotFound:
            return nil
        default:
            if Self.isTransientReadStatus(status) { throw KeychainError.temporarilyUnavailable(status) }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Compatibility accessor for non-critical preferences. Critical key material must call readData(for:).
    func data(for key: String) -> Data? {
        try? readData(for: key)
    }

    func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
