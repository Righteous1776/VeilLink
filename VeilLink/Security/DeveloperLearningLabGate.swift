import CryptoKit
import Foundation

/// Local authorization for developer-only board-training imports. The visible
/// input is an eight-digit PIN, but it is never stored in plaintext: a high-cost
/// verifier, device-local 256-bit secret and short-lived HMAC session capability
/// are all required before a training package may be injected.
@MainActor
final class DeveloperLearningLabGate: ObservableObject {
    @Published private(set) var isConfigured: Bool
    @Published private(set) var isAuthorized = false
    @Published private(set) var failedAttempts = 0
    @Published private(set) var authorizationExpiresAt: Date?
    @Published var errorMessage: String?

    private struct LockoutState: Codable {
        var failedAttempts: Int
        var lockedUntil: Date?
    }

    private enum Key {
        static let verifier = "board.developer-lab.verifier.v1"
        static let deviceSecret = "board.developer-lab.device-secret.v1"
        static let lockout = "board.developer-lab.lockout.v1"
    }

    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var sessionCapability: Data?
    private var lockedUntil: Date?

    init(keychain: KeychainStore) {
        self.keychain = keychain
        isConfigured = keychain.data(for: Key.verifier) != nil && keychain.data(for: Key.deviceSecret)?.count == 32
        if let data = keychain.data(for: Key.lockout),
           let state = try? decoder.decode(LockoutState.self, from: data),
           let deadline = state.lockedUntil,
           deadline > Date() {
            failedAttempts = state.failedAttempts
            lockedUntil = deadline
        } else {
            keychain.remove(Key.lockout)
        }
    }

    var isLockedOut: Bool {
        refreshExpiration()
        return lockedUntil.map { $0 > Date() } ?? false
    }

    /// Initial setup requires the existing application lock to be configured and
    /// currently unlocked. This keeps a passer-by from claiming the developer
    /// gate on a fresh install.
    func configure(pin: String, appLock: AppLockController) -> Bool {
        guard appLock.isEnabled, !appLock.isLocked else {
            errorMessage = "请先启用并解锁应用锁，才能初始化开发者训练密钥。"
            return false
        }
        guard Self.isEightDigitPIN(pin) else {
            errorMessage = "请输入 8 位数字开发者口令。"
            return false
        }
        do {
            let verifier = PasswordKDF.makeVerifier(pin, iterations: 240_000)
            let deviceSecret = PasswordKDF.randomData(count: 32)
            guard deviceSecret.count == 32 else { throw DeveloperLearningLabGateError.keyGeneration }
            try keychain.set(try encoder.encode(verifier), for: Key.verifier)
            try keychain.set(deviceSecret, for: Key.deviceSecret)
            isConfigured = true
            clearLockout()
            return establishSession(using: deviceSecret)
        } catch {
            errorMessage = "开发者训练密钥无法保存。"
            return false
        }
    }

    func unlock(pin: String) -> Bool {
        refreshExpiration()
        guard !isLockedOut else {
            errorMessage = "尝试次数过多，请在 \(Int(lockedUntil!.timeIntervalSinceNow.rounded(.up))) 秒后重试。"
            return false
        }
        guard Self.isEightDigitPIN(pin),
              let verifierData = keychain.data(for: Key.verifier),
              let verifier = try? decoder.decode(PasswordKDF.Verifier.self, from: verifierData),
              let deviceSecret = keychain.data(for: Key.deviceSecret),
              deviceSecret.count == 32,
              PasswordKDF.verify(pin, against: verifier) else {
            registerFailure()
            return false
        }
        clearLockout()
        return establishSession(using: deviceSecret)
    }

    func lock() {
        sessionCapability = nil
        authorizationExpiresAt = nil
        isAuthorized = false
    }

    func canImportTraining() -> Bool {
        refreshExpiration()
        return isAuthorized && sessionCapability?.count == 32
    }

    private func establishSession(using deviceSecret: Data) -> Bool {
        let nonce = PasswordKDF.randomData(count: 32)
        guard nonce.count == 32 else {
            errorMessage = "无法生成本次开发者会话。"
            return false
        }
        let capability = HMAC<SHA256>.authenticationCode(for: nonce, using: SymmetricKey(data: deviceSecret))
        sessionCapability = Data(capability)
        authorizationExpiresAt = Date().addingTimeInterval(10 * 60)
        isAuthorized = true
        errorMessage = nil
        return true
    }

    private func refreshExpiration() {
        if let expiry = authorizationExpiresAt, expiry <= Date() { lock() }
        if let deadline = lockedUntil, deadline <= Date() { clearLockout() }
    }

    private func registerFailure() {
        failedAttempts += 1
        if failedAttempts >= 8 { lockedUntil = Date().addingTimeInterval(10 * 60) }
        else if failedAttempts >= 5 { lockedUntil = Date().addingTimeInterval(60) }
        persistLockout()
        errorMessage = "开发者口令不正确。"
    }

    private func persistLockout() {
        if let data = try? encoder.encode(LockoutState(failedAttempts: failedAttempts, lockedUntil: lockedUntil)) {
            try? keychain.set(data, for: Key.lockout)
        }
    }

    private func clearLockout() {
        failedAttempts = 0
        lockedUntil = nil
        keychain.remove(Key.lockout)
    }

    private static func isEightDigitPIN(_ pin: String) -> Bool {
        pin.utf8.count == 8 && pin.utf8.allSatisfy { (48...57).contains($0) }
    }
}

private enum DeveloperLearningLabGateError: Error {
    case keyGeneration
}
