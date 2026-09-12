import Combine
import CryptoKit
import Foundation

enum IdentityError: LocalizedError {
    case profileLimitReached
    case passwordTooShort
    case missingIdentity
    case invalidDisplayName
    case invalidExport
    case cannotDeleteActiveIdentity

    var errorDescription: String? {
        switch self {
        case .profileLimitReached: return "本机最多保留 5 个身份。"
        case .passwordTooShort: return "账户密码至少需要 8 个字符。"
        case .missingIdentity: return "未找到本地身份。"
        case .invalidDisplayName: return "身份名称不能为空且不能超过 64 个 UTF-8 字节。"
        case .invalidExport: return "身份备份参数无效或内容已损坏。"
        case .cannotDeleteActiveIdentity: return "不能直接删除当前身份。请先切换到其他身份。"
        }
    }
}

@MainActor
final class IdentityManager: ObservableObject {
    static let profileLimit = 5

    @Published private(set) var profiles: [LocalIdentity] = []
    @Published private(set) var activeIdentity: LocalIdentity?

    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let profiles = "identity.profiles"
        static let activeID = "identity.active"
        static let deviceID = "device.id"
        static func secret(_ id: String) -> String { "identity.secret.\(id)" }
        static func password(_ id: String) -> String { "identity.password.\(id)" }
    }

    init(keychain: KeychainStore) {
        self.keychain = keychain
        load()
    }

    var primaryIdentity: LocalIdentity? {
        profiles.first(where: \.isPrimary)
    }

    var deviceID: String {
        if let data = keychain.data(for: Key.deviceID),
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        let value = UUID().uuidString
        try? keychain.set(Data(value.utf8), for: Key.deviceID)
        return value
    }

    @discardableResult
    func createProfile(displayName: String, password: String) throws -> LocalIdentity {
        guard profiles.count < Self.profileLimit else { throw IdentityError.profileLimitReached }
        guard password.count >= 8 else { throw IdentityError.passwordTooShort }
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, normalizedName.lengthOfBytes(using: .utf8) <= 64 else { throw IdentityError.invalidDisplayName }

        let signingKey = CryptoEngine.newIdentityKey()
        let publicKey = signingKey.publicKey.rawRepresentation
        let id = CryptoEngine.identityID(publicKey: publicKey)
        let profile = LocalIdentity(
            id: id,
            displayName: normalizedName,
            publicKey: publicKey,
            createdAt: Date(),
            isPrimary: profiles.isEmpty
        )
        let verifier = PasswordKDF.makeVerifier(password, iterations: 100_000)

        try keychain.set(signingKey.rawRepresentation, for: Key.secret(id))
        try keychain.set(try encoder.encode(verifier), for: Key.password(id))
        profiles.append(profile)
        activeIdentity = profile
        try persist()
        return profile
    }

    func switchProfile(to id: String, password: String) -> Bool {
        guard verifyPassword(password, for: id),
              let profile = profiles.first(where: { $0.id == id }) else { return false }
        activeIdentity = profile
        try? keychain.set(Data(id.utf8), for: Key.activeID)
        return true
    }


    @discardableResult
    func deleteProfile(id: String, password: String) throws -> LocalIdentity {
        guard activeIdentity?.id != id else { throw IdentityError.cannotDeleteActiveIdentity }
        guard verifyPassword(password, for: id), let profile = profiles.first(where: { $0.id == id }) else {
            throw IdentityError.missingIdentity
        }
        let previousProfiles = profiles
        let previousActive = activeIdentity
        profiles.removeAll(where: { $0.id == id })
        profiles = normalizedPrimaryProfiles(profiles)
        if let activeID = previousActive?.id {
            activeIdentity = profiles.first(where: { $0.id == activeID })
        }
        do {
            try persist()
        } catch {
            profiles = previousProfiles
            activeIdentity = previousActive
            throw error
        }
        keychain.remove(Key.secret(id))
        keychain.remove(Key.password(id))
        return profile
    }

    func verifyPassword(_ password: String, for identityID: String) -> Bool {
        guard let data = keychain.data(for: Key.password(identityID)),
              let verifier = try? decoder.decode(PasswordKDF.Verifier.self, from: data) else {
            return false
        }
        return PasswordKDF.verify(password, against: verifier)
    }

    func signingKey() throws -> Curve25519.Signing.PrivateKey {
        guard let id = activeIdentity?.id,
              let data = keychain.data(for: Key.secret(id)) else {
            throw IdentityError.missingIdentity
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    func encryptedRecoveryBundle(using backupKey: SymmetricKey) throws -> Data {
        var records: [IdentityRecoveryRecord] = []
        for profile in profiles {
            guard let secret = keychain.data(for: Key.secret(profile.id)),
                  let verifier = keychain.data(for: Key.password(profile.id)) else { throw IdentityError.missingIdentity }
            records.append(IdentityRecoveryRecord(profile: profile, signingKey: secret, passwordVerifier: verifier))
        }
        let cleartext = try encoder.encode(IdentityRecoveryBundle(version: 1, activeIdentityID: activeIdentity?.id, records: records))
        guard cleartext.count <= 128_000 else { throw IdentityError.missingIdentity }
        return try ChaChaPoly.seal(cleartext, using: backupKey).combined
    }

    func importRecoveryBundle(_ data: Data, using backupKey: SymmetricKey) throws {
        guard data.count <= 160_000 else { throw IdentityError.missingIdentity }
        let cleartext = try ChaChaPoly.open(try ChaChaPoly.SealedBox(combined: data), using: backupKey)
        let bundle = try decoder.decode(IdentityRecoveryBundle.self, from: cleartext)
        guard bundle.version == 1, bundle.records.count <= Self.profileLimit else { throw IdentityError.invalidExport }
        var restored: [LocalIdentity] = []; var seen = Set<String>()
        for record in bundle.records {
            guard seen.insert(record.profile.id).inserted, record.profile.publicKey.count == 32,
                  record.profile.id == CryptoEngine.identityID(publicKey: record.profile.publicKey),
                  !record.profile.displayName.isEmpty, record.profile.displayName.lengthOfBytes(using: .utf8) <= 64,
                  let verifier = try? decoder.decode(PasswordKDF.Verifier.self, from: record.passwordVerifier),
                  PasswordKDF.isSafeParameters(salt: verifier.salt, iterations: verifier.iterations, outputByteCount: verifier.digest.count, minimumIterations: PasswordKDF.minimumAcceptedIterations) else { throw IdentityError.missingIdentity }
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: record.signingKey)
            guard signingKey.publicKey.rawRepresentation == record.profile.publicKey else { throw IdentityError.missingIdentity }
            restored.append(record.profile)
        }
        let normalizedRestored = normalizedPrimaryProfiles(restored)
        let restoredIDs = Set(normalizedRestored.map(\.id))
        let restoredActive: LocalIdentity?
        if normalizedRestored.isEmpty {
            guard bundle.activeIdentityID == nil else { throw IdentityError.invalidExport }
            restoredActive = nil
        } else {
            guard let activeID = bundle.activeIdentityID, let active = normalizedRestored.first(where: { $0.id == activeID }) else { throw IdentityError.invalidExport }
            restoredActive = active
        }
        for old in profiles where !restoredIDs.contains(old.id) { keychain.remove(Key.secret(old.id)); keychain.remove(Key.password(old.id)) }
        for record in bundle.records { try keychain.set(record.signingKey, for: Key.secret(record.profile.id)); try keychain.set(record.passwordVerifier, for: Key.password(record.profile.id)) }
        profiles = normalizedRestored; activeIdentity = restoredActive; try persist()
    }

    func encryptedIdentityBundle(password: String) throws -> Data {
        guard let identity = activeIdentity,
              verifyPassword(password, for: identity.id),
              let secret = keychain.data(for: Key.secret(identity.id)) else {
            throw IdentityError.missingIdentity
        }
        let salt = PasswordKDF.randomData(count: 16)
        let iterations = 210_000
        let derived = PasswordKDF.derive(
            password: password,
            salt: salt,
            iterations: iterations,
            outputByteCount: 32
        )
        let sealed = try ChaChaPoly.seal(secret, using: SymmetricKey(data: derived))
        let bundle = IdentityExport(
            profile: identity,
            salt: salt,
            iterations: iterations,
            combinedCiphertext: sealed.combined
        )
        return try encoder.encode(bundle)
    }

    func importIdentityBundle(_ data: Data, password: String) throws -> LocalIdentity {
        guard data.count <= 16_384 else { throw IdentityError.invalidExport }
        let bundle = try decoder.decode(IdentityExport.self, from: data)
        guard PasswordKDF.isSafeParameters(salt: bundle.salt, iterations: bundle.iterations, outputByteCount: 32, minimumIterations: 100_000),
              bundle.profile.publicKey.count == 32, bundle.profile.id == CryptoEngine.identityID(publicKey: bundle.profile.publicKey),
              !bundle.profile.displayName.isEmpty, bundle.profile.displayName.lengthOfBytes(using: .utf8) <= 64, bundle.combinedCiphertext.count <= 256 else { throw IdentityError.invalidExport }
        let derived = PasswordKDF.derive(
            password: password,
            salt: bundle.salt,
            iterations: bundle.iterations,
            outputByteCount: 32
        )
        let box = try ChaChaPoly.SealedBox(combined: bundle.combinedCiphertext)
        let secret = try ChaChaPoly.open(box, using: SymmetricKey(data: derived))
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: secret)
        guard signingKey.publicKey.rawRepresentation == bundle.profile.publicKey else {
            throw IdentityError.missingIdentity
        }

        let importedProfile: LocalIdentity
        if let existing = profiles.first(where: { $0.id == bundle.profile.id }) {
            importedProfile = existing
        } else {
            guard profiles.count < Self.profileLimit else { throw IdentityError.profileLimitReached }
            var normalized = bundle.profile
            normalized.isPrimary = profiles.isEmpty
            profiles.append(normalized)
            importedProfile = normalized
        }
        let verifier = PasswordKDF.makeVerifier(password, iterations: 100_000)
        try keychain.set(secret, for: Key.secret(bundle.profile.id))
        try keychain.set(try encoder.encode(verifier), for: Key.password(bundle.profile.id))
        activeIdentity = importedProfile
        try persist()
        return importedProfile
    }

    private func load() {
        guard let data = keychain.data(for: Key.profiles),
              let saved = try? decoder.decode([LocalIdentity].self, from: data) else { return }
        let normalized = normalizedPrimaryProfiles(saved)
        profiles = normalized
        let activeID = keychain.data(for: Key.activeID).flatMap { String(data: $0, encoding: .utf8) }
        activeIdentity = normalized.first(where: { $0.id == activeID }) ?? normalized.first
        if normalized != saved { try? persist() }
    }

    private func normalizedPrimaryProfiles(_ input: [LocalIdentity]) -> [LocalIdentity] {
        guard !input.isEmpty else { return [] }
        var normalized = input
        let preferredPrimaryID = normalized.first(where: \.isPrimary)?.id ?? normalized.min(by: { $0.createdAt < $1.createdAt })?.id
        for index in normalized.indices {
            normalized[index].isPrimary = normalized[index].id == preferredPrimaryID
        }
        return normalized
    }

    private func persist() throws {
        try keychain.set(try encoder.encode(profiles), for: Key.profiles)
        if let id = activeIdentity?.id {
            try keychain.set(Data(id.utf8), for: Key.activeID)
        } else {
            keychain.remove(Key.activeID)
        }
    }
}

private struct IdentityRecoveryRecord: Codable { let profile: LocalIdentity; let signingKey: Data; let passwordVerifier: Data }
private struct IdentityRecoveryBundle: Codable { let version: Int; let activeIdentityID: String?; let records: [IdentityRecoveryRecord] }

private struct IdentityExport: Codable {
    let profile: LocalIdentity
    let salt: Data
    let iterations: Int
    let combinedCiphertext: Data
}
