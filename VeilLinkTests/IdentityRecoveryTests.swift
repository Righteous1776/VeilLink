import CryptoKit
import XCTest
@testable import VeilLink

@MainActor
final class IdentityRecoveryTests: XCTestCase {
    func testRecoveryBundleRestoresAllProfilesAndPasswords() throws {
        let source = IdentityManager(keychain: KeychainStore(service: "studio.zeo.veillink.tests.source.\(UUID().uuidString)"))
        let first = try source.createProfile(displayName: "Alice", password: "alice-pass-123")
        let second = try source.createProfile(displayName: "Bob", password: "bob-pass-456")
        let key = SymmetricKey(size: .bits256); let bundle = try source.encryptedRecoveryBundle(using: key)
        let target = IdentityManager(keychain: KeychainStore(service: "studio.zeo.veillink.tests.target.\(UUID().uuidString)"))
        try target.importRecoveryBundle(bundle, using: key)
        XCTAssertEqual(Set(target.profiles.map(\.id)), Set([first.id, second.id])); XCTAssertEqual(target.activeIdentity?.id, second.id)
        XCTAssertTrue(target.verifyPassword("alice-pass-123", for: first.id)); XCTAssertTrue(target.verifyPassword("bob-pass-456", for: second.id))
    }

    func testRecoveryBundleRejectsWrongBackupKey() throws {
        let source = IdentityManager(keychain: KeychainStore(service: "studio.zeo.veillink.tests.source.\(UUID().uuidString)"))
        _ = try source.createProfile(displayName: "Alice", password: "alice-pass-123")
        let bundle = try source.encryptedRecoveryBundle(using: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try source.importRecoveryBundle(bundle, using: SymmetricKey(size: .bits256)))
    }
    func testSingleImportedSecondaryIdentityBecomesPrimaryOnFreshDevice() throws {
        let sourceKeychain = KeychainStore(service: "studio.zeo.veillink.tests.identity.source.\(UUID().uuidString)")
        let destinationKeychain = KeychainStore(service: "studio.zeo.veillink.tests.identity.destination.\(UUID().uuidString)")
        let source = IdentityManager(keychain: sourceKeychain)
        _ = try source.createProfile(displayName: "Primary", password: "primary-pass-123")
        let secondary = try source.createProfile(displayName: "Secondary", password: "secondary-pass-123")
        XCTAssertFalse(secondary.isPrimary)
        let bundle = try source.encryptedIdentityBundle(password: "secondary-pass-123")

        let destination = IdentityManager(keychain: destinationKeychain)
        let imported = try destination.importIdentityBundle(bundle, password: "secondary-pass-123")
        XCTAssertTrue(imported.isPrimary)
        XCTAssertEqual(destination.primaryIdentity?.id, imported.id)
        XCTAssertEqual(destination.profiles.filter { $0.isPrimary }.count, 1)
    }

}
