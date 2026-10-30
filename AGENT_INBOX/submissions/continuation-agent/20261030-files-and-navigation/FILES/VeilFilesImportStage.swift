import Foundation

/// A temporary, app-owned file snapshot for user-selected Files documents.
/// Capture is coordinated with Files/iCloud providers before the picker URL is
/// retained across a sheet, a Task, or a potentially destructive restore.
enum VeilFilesImportStage {
    enum StageError: LocalizedError {
        case unsupportedSource
        case notAFile
        case tooLarge
        case cannotRead
        var errorDescription: String? {
            switch self {
            case .unsupportedSource: return "只接受从系统“文件”选择器导入的本地文档。"
            case .notAFile: return "所选项目不是普通文件。"
            case .tooLarge: return "所选文件超出了该工具允许的大小。"
            case .cannotRead: return "无法读取所选文件。请确认 iCloud 文件已下载，并重新选择。"
            }
        }
    }

    /// Not a global product limit; callers must select an appropriate per-operation budget.
    static func stage(_ source: URL, maximumBytes: Int64) throws -> URL {
        guard source.isFileURL else { throw StageError.unsupportedSource }
        guard maximumBytes > 0 else { throw StageError.tooLarge }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        let root = cacheRoot()
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        // Never trust the original name/path for an app-owned temporary destination.
        let ext = source.pathExtension
        let safeExt = ext.count <= 12 && !ext.isEmpty &&
            ext.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }
        let destination = folder.appendingPathComponent("selected")
            .appendingPathExtension(safeExt ? ext.lowercased() : "bin")
        var copyFailure: Error?
        var coordinationFailure: NSError?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationFailure) { readable in
            do {
                let attributes = try fileManager.attributesOfItem(atPath: readable.path)
                guard (attributes[.type] as? FileAttributeType) == .typeRegular else {
                    throw StageError.notAFile
                }
                guard let originalSize = attributes[.size] as? NSNumber,
                      originalSize.int64Value <= maximumBytes else {
                    throw StageError.tooLarge
                }
                try fileManager.copyItem(at: readable, to: destination)
                let copied = try fileManager.attributesOfItem(atPath: destination.path)
                guard let copiedBytes = copied[.size] as? NSNumber,
                      copiedBytes.int64Value <= maximumBytes,
                      copiedBytes.int64Value == originalSize.int64Value else {
                    throw StageError.tooLarge
                }
            } catch {
                copyFailure = error
            }
        }
        if coordinationFailure != nil || copyFailure != nil {
            try? fileManager.removeItem(at: folder)
            if let problem = copyFailure as? StageError { throw problem }
            throw StageError.cannotRead
        }
        return destination
    }

    /// Hash or inspect a large Files document without duplicating it in Caches.
    /// Keep security scope and file-provider coordination alive for the whole read.
    static func withCoordinatedRead<T>(
        _ source: URL,
        _ body: (URL) throws -> T
    ) throws -> T {
        guard source.isFileURL else { throw StageError.unsupportedSource }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationFailure: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationFailure) { readable in
            result = Result { try body(readable) }
        }
        if let coordinationFailure { throw coordinationFailure }
        guard let result else { throw StageError.cannotRead }
        return try result.get()
    }

    static func discard(_ staged: URL) {
        guard staged.isFileURL else { return }
        let folder = staged.deletingLastPathComponent().standardizedFileURL
        let root = cacheRoot().standardizedFileURL
        // Scope is one immediate UUID folder only; never delete arbitrary Files URLs.
        guard folder.deletingLastPathComponent() == root,
              UUID(uuidString: folder.lastPathComponent) != nil,
              staged.lastPathComponent.hasPrefix("selected.") else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    private static func cacheRoot() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VeilLinkFileImportStage", isDirectory: true)
    }
}
