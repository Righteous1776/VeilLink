import Foundation

/// Strict ownership and crash-recovery policy for Files-provider import snapshots.
/// This policy never reads or mutates the source provider URL.
enum VeilImportStagingLeasePolicy {
    static let folderName = "VeilLink-Import-Staging"
    static let defaultLifetime: TimeInterval = 24 * 60 * 60

    struct SweepReport: Equatable {
        let removed: Int
        let retained: Int
        let failed: Int
    }

    static func stagingRoot(temporaryDirectory: URL = FileManager.default.temporaryDirectory) -> URL {
        temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Only a direct file in a single UUID lease directory is eligible.
    static func owns(_ stagedFile: URL, root: URL = stagingRoot(), fileManager: FileManager = .default) -> Bool {
        guard stagedFile.isFileURL, root.isFileURL else { return false }
        let item = stagedFile.standardizedFileURL
        let lease = item.deletingLastPathComponent()
        let anchor = root.standardizedFileURL
        guard lease.deletingLastPathComponent() == anchor,
              UUID(uuidString: lease.lastPathComponent) != nil,
              item.lastPathComponent != ".", item.lastPathComponent != "..",
              isActualDirectory(lease, fileManager: fileManager),
              isActualRegularFile(item),
              isActualDirectory(anchor, fileManager: fileManager) else { return false }
        return true
    }

    /// Never delete arbitrary user paths that merely contain the folder name.
    @discardableResult
    static func removeOwnedCopy(_ stagedFile: URL, root: URL = stagingRoot(), fileManager: FileManager = .default) throws -> Bool {
        guard owns(stagedFile, root: root, fileManager: fileManager) else { return false }
        try fileManager.removeItem(at: stagedFile.standardizedFileURL.deletingLastPathComponent())
        return true
    }

    /// Recover interrupted imports at a future launch/foreground.
    /// Symlink directories and entries without reliable timestamps are retained.
    /// Pass the current active lease set; no live lease can be swept.
    static func sweepExpired(
        root: URL = stagingRoot(),
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime,
        maxRemovals: Int = 64,
        activeLeaseIDs: Set<UUID>,
        fileManager: FileManager = .default
    ) throws -> SweepReport {
        guard lifetime > 0, maxRemovals > 0 else { return SweepReport(removed: 0, retained: 0, failed: 0) }
        guard fileManager.fileExists(atPath: root.path) else { return SweepReport(removed: 0, retained: 0, failed: 0) }
        guard isActualDirectory(root.standardizedFileURL, fileManager: fileManager) else {
            return SweepReport(removed: 0, retained: 0, failed: 1)
        }
        let entries = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey, .contentModificationDateKey],
            options: []
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        var removed = 0
        var retained = 0
        var failed = 0
        for entry in entries {
            guard let leaseID = UUID(uuidString: entry.lastPathComponent),
                  !activeLeaseIDs.contains(leaseID),
                  entry.standardizedFileURL.deletingLastPathComponent() == root.standardizedFileURL,
                  isActualDirectory(entry, fileManager: fileManager) else {
                retained += 1
                continue
            }
            let values = try? entry.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            guard let created = values?.creationDate else { retained += 1; continue }
            let newest = max(created, values?.contentModificationDate ?? created)
            guard newest <= now.addingTimeInterval(-lifetime), removed < maxRemovals else {
                retained += 1
                continue
            }
            do { try fileManager.removeItem(at: entry); removed += 1 }
            catch { failed += 1 }
        }
        return SweepReport(removed: removed, retained: retained, failed: failed)
    }

    private static func isActualRegularFile(_ url: URL) -> Bool {
        guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
        return v.isRegularFile == true && v.isSymbolicLink != true
    }

    private static func isActualDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }
}
