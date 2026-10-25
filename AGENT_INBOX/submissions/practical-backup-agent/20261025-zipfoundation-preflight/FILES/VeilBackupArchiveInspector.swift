import Foundation
import ZIPFoundation

/// Runs on a non-main executor; never extracts the archive to disk, changes
/// SQLite or asks for backup credentials. This is not a decryption check.
enum VeilBackupArchiveInspector {
    private struct ManifestHeader: Decodable {
        let format: String
        let version: Int
        let createdAt: Date
        let identityID: String
        let salt: Data
        let iterations: Int
    }

    static func inspect(_ url: URL, verifyAllCRC: Bool) -> VeilBackupPreflightPolicy.Report {
        let policy = VeilBackupPreflightPolicy.self
        let empty = policy.evaluate([], zipBytes: 0)
        guard url.isFileURL else { return empty.appending([.damagedArchive]) }
        #if canImport(Darwin)
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
        #endif
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let rawSize = values.fileSize, rawSize > 0 else {
                return empty.appending([.damagedArchive])
            }
            let byteCount = UInt64(rawSize)
            if byteCount > policy.maxArchiveBytes {
                return policy.evaluate([], zipBytes: byteCount)
            }
            let archive = try Archive(url: url, accessMode: .read)
            var descriptors: [VeilBackupPreflightPolicy.EntryInfo] = []
            descriptors.reserveCapacity(32)
            var manifestEntry: Entry?
            for entry in archive {
                if descriptors.count > policy.maxEntryCount { break }
                let kind: VeilBackupPreflightPolicy.Kind
                switch entry.type {
                case .file: kind = .file
                case .directory: kind = .directory
                case .symlink: kind = .symlink
                @unknown default: kind = .other
                }
                descriptors.append(.init(path: entry.path, kind: kind,
                                         compressedBytes: entry.compressedSize,
                                         expandedBytes: entry.uncompressedSize))
                if entry.path == "manifest.json", kind == .file { manifestEntry = entry }
            }
            var report = policy.evaluate(descriptors, zipBytes: byteCount)
            guard report.permittedToRestore else { return report }
            guard let manifestEntry,
                  manifestEntry.uncompressedSize <= policy.maxManifestBytes else {
                return report.appending([.invalidManifest])
            }
            var manifestBytes = Data()
            manifestBytes.reserveCapacity(Int(manifestEntry.uncompressedSize))
            let manifestCRC = try archive.extract(manifestEntry, bufferSize: 16 * 1024,
                                                  skipCRC32: false) { bytes in
                guard manifestBytes.count <= Int(policy.maxManifestBytes) - bytes.count else {
                    throw VeilBackupPreflightError.invalidContent
                }
                manifestBytes.append(bytes)
            }
            guard manifestCRC == manifestEntry.checksum,
                  manifestBytes.count == Int(manifestEntry.uncompressedSize) else {
                return report.appending([.crcMismatch])
            }
            let header: ManifestHeader
            do { header = try JSONDecoder().decode(ManifestHeader.self, from: manifestBytes) }
            catch { return report.appending([.invalidManifest]) }
            guard header.format == "VeilLinkBackup", [1, 2].contains(header.version),
                  !header.identityID.isEmpty, header.identityID.utf8.count <= 128,
                  (16...64).contains(header.salt.count),
                  (100_000...1_000_000).contains(header.iterations) else {
                return report.appending([.invalidManifest])
            }
            report = report.appending([], version: header.version, createdAt: header.createdAt)
            if verifyAllCRC {
                do {
                    for entry in archive where entry.type == .file {
                        var received: UInt64 = 0
                        let computed = try archive.extract(entry, bufferSize: 32 * 1024,
                                                           skipCRC32: false) { data in
                            let (next, overflow) = received.addingReportingOverflow(UInt64(data.count))
                            guard !overflow, next <= entry.uncompressedSize else {
                                throw VeilBackupPreflightError.invalidContent
                            }
                            received = next
                        }
                        guard computed == entry.checksum, received == entry.uncompressedSize else {
                            return report.appending([.crcMismatch])
                        }
                    }
                } catch { return report.appending([.crcMismatch]) }
                report = report.appending([], crcVerified: true)
            }
            return report
        } catch {
            return empty.appending([.damagedArchive])
        }
    }
}

private enum VeilBackupPreflightError: Error { case invalidContent }