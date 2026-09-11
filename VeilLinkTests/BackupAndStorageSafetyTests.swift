import XCTest
@testable import VeilLink

@MainActor
final class BackupAndStorageSafetyTests: XCTestCase {
    private func temporaryRoot(_ prefix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    func testExistingDatabaseWithoutKeyFailsClosed() throws {
        let root = temporaryRoot("VeilLink-KeyMissing")
        defer { try? FileManager.default.removeItem(at: root) }

        let firstKeychain = KeychainStore(service: "studio.zeo.veillink.tests.key-a.\(UUID().uuidString)")
        _ = try DatabaseStore(keychain: firstKeychain, rootDirectory: root)

        let unrelatedKeychain = KeychainStore(service: "studio.zeo.veillink.tests.key-b.\(UUID().uuidString)")
        XCTAssertThrowsError(try DatabaseStore(keychain: unrelatedKeychain, rootDirectory: root)) { error in
            guard let databaseError = error as? DatabaseError else {
                return XCTFail("Expected DatabaseError, got \(error)")
            }
            guard case .encryptionKeyMissing = databaseError else {
                return XCTFail("Expected encryptionKeyMissing, got \(databaseError)")
            }
        }
    }

    func testWrongExistingStorageKeyIsDetectedByMarker() throws {
        let root = temporaryRoot("VeilLink-KeyMismatch")
        defer { try? FileManager.default.removeItem(at: root) }

        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.key-mismatch.\(UUID().uuidString)")
        _ = try DatabaseStore(keychain: keychain, rootDirectory: root)
        try keychain.set(PasswordKDF.randomData(count: 32), for: "storage.database.key")

        XCTAssertThrowsError(try DatabaseStore(keychain: keychain, rootDirectory: root)) { error in
            guard let databaseError = error as? DatabaseError else {
                return XCTFail("Expected DatabaseError, got \(error)")
            }
            guard case .encryptionKeyMismatch = databaseError else {
                return XCTFail("Expected encryptionKeyMismatch, got \(databaseError)")
            }
        }
    }

    func testIndependentBackupPasswordRestoresIntoFreshIdentityState() throws {
        let sourceRoot = temporaryRoot("VeilLink-BackupSource")
        let targetRoot = temporaryRoot("VeilLink-BackupTarget")
        defer {
            try? FileManager.default.removeItem(at: sourceRoot)
            try? FileManager.default.removeItem(at: targetRoot)
        }

        let sourceKeychain = KeychainStore(service: "studio.zeo.veillink.tests.backup-source.\(UUID().uuidString)")
        let sourceStore = try DatabaseStore(keychain: sourceKeychain, rootDirectory: sourceRoot)
        let sourceIdentity = IdentityManager(keychain: sourceKeychain)
        let profile = try sourceIdentity.createProfile(displayName: "Alice", password: "identity-pass-123")
        try sourceStore.upsertProfile(profile)
        let sourceBackup = BackupManager(database: sourceStore, identity: sourceIdentity)

        let archive = try sourceBackup.exportBackup(password: "different-backup-pass-456")
        defer { try? FileManager.default.removeItem(at: archive) }

        let targetKeychain = KeychainStore(service: "studio.zeo.veillink.tests.backup-target.\(UUID().uuidString)")
        let targetStore = try DatabaseStore(keychain: targetKeychain, rootDirectory: targetRoot)
        let targetIdentity = IdentityManager(keychain: targetKeychain)
        XCTAssertNil(targetIdentity.activeIdentity)

        let targetBackup = BackupManager(database: targetStore, identity: targetIdentity)
        try targetBackup.restoreBackup(from: archive, password: "different-backup-pass-456")

        XCTAssertEqual(targetIdentity.activeIdentity?.id, profile.id)
        XCTAssertTrue(targetIdentity.verifyPassword("identity-pass-123", for: profile.id))
        XCTAssertEqual(targetStore.integrityCheck().lowercased(), "ok")
    }
}
