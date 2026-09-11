import CryptoKit
import Foundation
import ZIPFoundation

enum BackupError: LocalizedError {
    case passwordTooShort
    case invalidPackage
    case corruptedPackage

    var errorDescription: String? {
        switch self {
        case .passwordTooShort: return "备份密码至少需要 8 个字符。"
        case .invalidPackage: return "这不是有效的 VeilLink 备份包。"
        case .corruptedPackage: return "备份包损坏或密码不正确。"
        }
    }
}

struct BackupManifest: Codable {
    let format: String
    let version: Int
    let createdAt: Date
    let identityID: String
    let salt: Data
    let iterations: Int
}

final class BackupManager {
    private static let maxArchiveBytes = 200 * 1024 * 1024
    private static let maxExtractedBytes = 350 * 1024 * 1024
    private static let maxExtractedFiles = 10_000
    private let database: DatabaseStore
    private let identity: IdentityManager
    private let fileManager = FileManager.default

    init(database: DatabaseStore, identity: IdentityManager) {
        self.database = database
        self.identity = identity
    }

    @MainActor
    func exportBackup(password: String) throws -> URL {
        guard password.count >= 8 else { throw BackupError.passwordTooShort }
        guard let activeIdentity = identity.activeIdentity else { throw IdentityError.missingIdentity }

        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VeilLink-Export-\(UUID().uuidString)", isDirectory: true)
        let staging = root.appendingPathComponent("Payload", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let snapshot = root.appendingPathComponent("snapshot.sqlite")
        try database.createConsistentSnapshot(at: snapshot)

        let salt = PasswordKDF.randomData(count: 16)
        let iterations = 210_000
        let keyData = PasswordKDF.derive(
            password: password,
            salt: salt,
            iterations: iterations,
            outputByteCount: 32
        )
        let key = SymmetricKey(data: keyData)

        let databaseData = try Data(contentsOf: snapshot)
        let encryptedDatabase = try ChaChaPoly.seal(databaseData, using: key).combined
        try encryptedDatabase.write(
            to: staging.appendingPathComponent("database.enc"),
            options: [.atomic, .completeFileProtection]
        )

        let wrappedStorageKey = try database.wrappedStorageKey(using: key)
        try wrappedStorageKey.write(
            to: staging.appendingPathComponent("storage-key.enc"),
            options: [.atomic, .completeFileProtection]
        )

        let identityBundle = try identity.encryptedRecoveryBundle(using: key)
        try identityBundle.write(
            to: staging.appendingPathComponent("identity.enc"),
            options: [.atomic, .completeFileProtection]
        )

        let manifest = BackupManifest(
            format: "VeilLinkBackup",
            version: 2,
            createdAt: Date(),
            identityID: activeIdentity.id,
            salt: salt,
            iterations: iterations
        )
        try JSONEncoder().encode(manifest).write(
            to: staging.appendingPathComponent("manifest.json"),
            options: [.atomic, .completeFileProtection]
        )

        let encryptedAttachments = staging.appendingPathComponent("attachments", isDirectory: true)
        try fileManager.createDirectory(at: encryptedAttachments, withIntermediateDirectories: true)
        let attachmentFiles = (try? fileManager.contentsOfDirectory(
            at: database.attachmentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for file in attachmentFiles where !file.hasDirectoryPath {
            let plaintext = try Data(contentsOf: file)
            let ciphertext = try ChaChaPoly.seal(plaintext, using: key).combined
            try ciphertext.write(to: encryptedAttachments.appendingPathComponent(file.lastPathComponent), options: .atomic)
        }

        let exports = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let destination = exports.appendingPathComponent("VeilLink-\(formatter.string(from: Date())).zip")
        try? fileManager.removeItem(at: destination)
        try fileManager.zipItem(at: staging, to: destination, shouldKeepParent: false)
        return destination
    }

    @MainActor
    func restoreBackup(from archiveURL: URL, password: String) throws {
        guard password.count >= 8 else { throw BackupError.passwordTooShort }
        let archiveSize = try archiveURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard archiveSize > 0, archiveSize <= Self.maxArchiveBytes else { throw BackupError.invalidPackage }
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VeilLink-Restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        try validateArchiveBeforeExtraction(archiveURL)
        try fileManager.unzipItem(at: archiveURL, to: root)
        try validateExtractedTree(root)

        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(BackupManifest.self, from: data),
              manifest.format == "VeilLinkBackup",
              (manifest.version == 1 || manifest.version == 2),
              manifest.identityID.count <= 128,
              PasswordKDF.isSafeParameters(salt: manifest.salt, iterations: manifest.iterations, outputByteCount: 32, minimumIterations: 100_000) else {
            throw BackupError.invalidPackage
        }
        let keyData = PasswordKDF.derive(
            password: password,
            salt: manifest.salt,
            iterations: manifest.iterations,
            outputByteCount: 32
        )
        let key = SymmetricKey(data: keyData)

        let preparedAttachments = root.appendingPathComponent("prepared-attachments", isDirectory: true)
        try fileManager.createDirectory(at: preparedAttachments, withIntermediateDirectories: true)
        let encryptedAttachmentsURL = root.appendingPathComponent("attachments", isDirectory: true)
        let encryptedAttachmentFiles = (try? fileManager.contentsOfDirectory(
            at: encryptedAttachmentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for file in encryptedAttachmentFiles where !file.hasDirectoryPath {
            guard file.deletingLastPathComponent().standardizedFileURL == encryptedAttachmentsURL.standardizedFileURL else {
                throw BackupError.invalidPackage
            }
            let ciphertext = try Data(contentsOf: file)
            let box = try ChaChaPoly.SealedBox(combined: ciphertext)
            let plaintext = try ChaChaPoly.open(box, using: key)
            try plaintext.write(to: preparedAttachments.appendingPathComponent(file.lastPathComponent), options: .atomic)
        }

        guard let encryptedDatabase = try? Data(contentsOf: root.appendingPathComponent("database.enc")),
              let box = try? ChaChaPoly.SealedBox(combined: encryptedDatabase),
              let databaseData = try? ChaChaPoly.open(box, using: key) else {
            throw BackupError.corruptedPackage
        }

        let rollback = root.appendingPathComponent("pre-restore.sqlite")
        try database.createConsistentSnapshot(at: rollback)
        let rollbackStorageKey = try database.wrappedStorageKey(using: key)
        let rollbackIdentityBundle = try identity.encryptedRecoveryBundle(using: key)
        let rollbackAttachments = root.appendingPathComponent("previous-attachments", isDirectory: true)
        let restored = root.appendingPathComponent("restored.sqlite")
        try databaseData.write(to: restored, options: [.atomic, .completeFileProtection])
        try database.validateSnapshot(at: restored)

        let identityData = try Data(contentsOf: root.appendingPathComponent("identity.enc"))

        do {
            let wrappedStorageKey = try Data(contentsOf: root.appendingPathComponent("storage-key.enc"))
            try database.installWrappedStorageKey(wrappedStorageKey, using: key)
            try database.replaceDatabase(with: restored)
            try database.verifyStorageKey()
            if manifest.version == 2 {
                try identity.importRecoveryBundle(identityData, using: key)
                guard identity.activeIdentity?.id == manifest.identityID else { throw BackupError.corruptedPackage }
            } else {
                let imported = try identity.importIdentityBundle(identityData, password: password)
                guard imported.id == manifest.identityID else { throw BackupError.corruptedPackage }
            }
            if fileManager.fileExists(atPath: database.attachmentsURL.path) {
                try fileManager.moveItem(at: database.attachmentsURL, to: rollbackAttachments)
            }
            try fileManager.moveItem(at: preparedAttachments, to: database.attachmentsURL)
        } catch {
            try? database.replaceDatabase(with: rollback)
            try? database.installWrappedStorageKey(rollbackStorageKey, using: key)
            try? database.verifyStorageKey()
            try? identity.importRecoveryBundle(rollbackIdentityBundle, using: key)
            if fileManager.fileExists(atPath: rollbackAttachments.path) {
                try? fileManager.removeItem(at: database.attachmentsURL)
                try? fileManager.moveItem(at: rollbackAttachments, to: database.attachmentsURL)
            }
            throw error
        }
    }

    private func validateArchiveBeforeExtraction(_ archiveURL: URL) throws {
        let archive = try Archive(url: archiveURL, accessMode: .read)
        var fileCount = 0
        var totalBytes: UInt64 = 0
        for entry in archive {
            let isDirectory = entry.type == .directory
            guard entry.type != .symlink,
                  entry.path.utf8.count <= 1_024,
                  isAllowedBackupPath(entry.path, isDirectory: isDirectory) else {
                throw BackupError.invalidPackage
            }
            guard !isDirectory else { continue }
            fileCount += 1
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, fileCount <= Self.maxExtractedFiles, nextTotal <= UInt64(Self.maxExtractedBytes) else {
                throw BackupError.invalidPackage
            }
            totalBytes = nextTotal
        }
    }

    private func isAllowedBackupPath(_ rawPath: String, isDirectory: Bool) -> Bool {
        guard !rawPath.isEmpty, !rawPath.contains("\0"), !rawPath.hasPrefix("/"), !rawPath.hasPrefix("\\") else { return false }
        let normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.contains("."), !components.contains("..") else { return false }

        if isDirectory {
            return components == ["attachments"]
        }
        if components.count == 1 {
            return ["manifest.json", "database.enc", "storage-key.enc", "identity.enc"].contains(components[0])
        }
        guard components.count == 2, components[0] == "attachments", components[1].hasSuffix(".bin") else { return false }
        let stem = String(components[1].dropLast(4))
        return UUID(uuidString: stem) != nil
    }

    private func validateExtractedTree(_ root: URL) throws {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { throw BackupError.invalidPackage }

        var fileCount = 0
        var totalBytes = 0
        let rootPath = root.standardizedFileURL.path + "/"
        for case let url as URL in enumerator {
            let standardized = url.standardizedFileURL
            guard standardized.path.hasPrefix(rootPath) else { throw BackupError.invalidPackage }
            let relativePath = String(standardized.path.dropFirst(rootPath.count))
            let values = try standardized.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true { throw BackupError.invalidPackage }
            let isDirectory = values.isDirectory == true
            guard isAllowedBackupPath(relativePath, isDirectory: isDirectory) else { throw BackupError.invalidPackage }
            guard values.isRegularFile == true else { continue }
            fileCount += 1
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(values.fileSize ?? 0)
            guard !overflow, fileCount <= Self.maxExtractedFiles, nextTotal <= Self.maxExtractedBytes else { throw BackupError.invalidPackage }
            totalBytes = nextTotal
        }

        let required = ["manifest.json", "database.enc", "storage-key.enc", "identity.enc"]
        for file in required where !fileManager.fileExists(atPath: root.appendingPathComponent(file).path) {
            throw BackupError.invalidPackage
        }
    }
}
