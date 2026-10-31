import XCTest
@testable import VeilLink

@MainActor
final class DeveloperLearningLabGateTests: XCTestCase {
    func testDeveloperLabRequiresUnlockedAppLockForFirstEnrollment() {
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.developer-lab.\(UUID().uuidString)")
        let appLock = AppLockController(keychain: keychain)
        let gate = DeveloperLearningLabGate(keychain: keychain)

        XCTAssertFalse(gate.configure(pin: "12345678", appLock: appLock))
        XCTAssertFalse(gate.isConfigured)

        XCTAssertTrue(appLock.configure(pin: "123456"))
        XCTAssertTrue(gate.configure(pin: "12345678", appLock: appLock))
        XCTAssertTrue(gate.isConfigured)
        XCTAssertTrue(gate.canImportTraining())
    }

    func testDeveloperLabStoresNoPlainPINAndLocksSession() {
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.developer-lab.\(UUID().uuidString)")
        let appLock = AppLockController(keychain: keychain)
        XCTAssertTrue(appLock.configure(pin: "123456"))
        let gate = DeveloperLearningLabGate(keychain: keychain)
        XCTAssertTrue(gate.configure(pin: "87654321", appLock: appLock))
        gate.lock()
        XCTAssertFalse(gate.canImportTraining())
        XCTAssertFalse(gate.unlock(pin: "00000000"))
        XCTAssertTrue(gate.unlock(pin: "87654321"))
        XCTAssertTrue(gate.canImportTraining())
        let verifier = keychain.data(for: "board.developer-lab.verifier.v1")
        XCTAssertNotNil(verifier)
        // Data.contains(Data) requires iOS 16; Data.range(of:) is supported by the iOS 15 target.
        XCTAssertNil(verifier?.range(of: Data("87654321".utf8)))
    }
}
