import Combine
import Foundation
import LocalAuthentication

@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var failedAttempts = 0
    @Published var errorMessage: String?

    private struct LockoutState: Codable { var failedAttempts: Int; var lockedUntil: Date? }
    private let keychain: KeychainStore
    private let verifierKey = "app.lock.verifier"
    private let lockoutKey = "app.lock.lockout"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var lockedUntil: Date?

    init(keychain: KeychainStore) {
        self.keychain = keychain
        let enabled = keychain.data(for: verifierKey) != nil
        isEnabled = enabled
        isLocked = enabled
        if let data = keychain.data(for: lockoutKey), let state = try? decoder.decode(LockoutState.self, from: data) {
            if let deadline = state.lockedUntil {
                if deadline > Date() {
                    failedAttempts = max(0, state.failedAttempts)
                    lockedUntil = deadline
                } else {
                    keychain.remove(lockoutKey)
                }
            } else {
                failedAttempts = max(0, min(state.failedAttempts, 7))
                if failedAttempts == 0 { keychain.remove(lockoutKey) }
            }
        } else {
            keychain.remove(lockoutKey)
        }
    }

    func configure(pin: String) -> Bool {
        guard pin.utf8.count == 6, pin.utf8.allSatisfy({ (48...57).contains($0) }) else { errorMessage = "请输入 6 位数字。"; return false }
        do {
            let verifier = PasswordKDF.makeVerifier(pin, iterations: 60_000)
            try keychain.set(try encoder.encode(verifier), for: verifierKey)
            isEnabled = true; isLocked = false; clearLockout(); return true
        } catch { errorMessage = "应用锁保存失败。"; return false }
    }

    func unlock(pin: String) -> Bool {
        refreshExpiredLockout()
        if let lockedUntil, lockedUntil > Date() {
            errorMessage = "尝试次数过多，请在 \(Int(lockedUntil.timeIntervalSinceNow.rounded(.up))) 秒后重试。"; return false
        }
        guard let data = keychain.data(for: verifierKey), let verifier = try? decoder.decode(PasswordKDF.Verifier.self, from: data) else { return false }
        guard PasswordKDF.verify(pin, against: verifier) else {
            failedAttempts += 1
            if failedAttempts >= 8 { lockedUntil = Date().addingTimeInterval(300) }
            else if failedAttempts >= 5 { lockedUntil = Date().addingTimeInterval(30) }
            persistLockout(); errorMessage = "密码不正确"; return false
        }
        clearLockout(); errorMessage = nil; isLocked = false; return true
    }

    func unlockWithBiometrics() async -> Bool {
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return false }
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 VeilLink")
            if result { clearLockout(); isLocked = false }
            return result
        } catch { return false }
    }

    func lock() { guard isEnabled else { return }; isLocked = true }
    func disable(pin: String) -> Bool { guard unlock(pin: pin) else { return false }; keychain.remove(verifierKey); clearLockout(); isEnabled = false; isLocked = false; return true }
    func changePIN(current: String, new: String) -> Bool { guard unlock(pin: current) else { return false }; return configure(pin: new) }

    private func refreshExpiredLockout() { guard let lockedUntil, lockedUntil <= Date() else { return }; clearLockout() }
    private func persistLockout() { if let data = try? encoder.encode(LockoutState(failedAttempts: failedAttempts, lockedUntil: lockedUntil)) { try? keychain.set(data, for: lockoutKey) } }
    private func clearLockout() { failedAttempts = 0; lockedUntil = nil; keychain.remove(lockoutKey) }
}
