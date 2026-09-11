import XCTest
@testable import VeilLink

@MainActor
final class OwnerModeControllerTests: XCTestCase {
    func testLocalOwnerAuthorizationAlwaysUsesPrimaryIdentityPassword() throws {
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.owner.\(UUID().uuidString)")
        let identities = IdentityManager(keychain: keychain)
        let primary = try identities.createProfile(displayName: "Primary", password: "primary-pass-123")
        let secondary = try identities.createProfile(displayName: "Secondary", password: "secondary-pass-456")
        XCTAssertEqual(identities.activeIdentity?.id, secondary.id)
        XCTAssertEqual(identities.primaryIdentity?.id, primary.id)

        let owner = OwnerModeController()
        XCTAssertFalse(owner.authorizeLocal(password: "secondary-pass-456", identity: identities))
        XCTAssertFalse(owner.isUnlocked)
        XCTAssertTrue(owner.authorizeLocal(password: "primary-pass-123", identity: identities))
        XCTAssertTrue(owner.isUnlocked)
        owner.lock()
    }

    func testOwnerLockClearsCapabilities() throws {
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.owner.expiry.\(UUID().uuidString)")
        let identities = IdentityManager(keychain: keychain)
        _ = try identities.createProfile(displayName: "Primary", password: "primary-pass-123")
        let owner = OwnerModeController()
        XCTAssertTrue(owner.authorizeLocal(password: "primary-pass-123", identity: identities))
        XCTAssertTrue(owner.isAuthorized(for: .diagnostics))
        owner.lock()
        XCTAssertFalse(owner.isAuthorized(for: .diagnostics))
    }
}
