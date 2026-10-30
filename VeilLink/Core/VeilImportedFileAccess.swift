import Foundation

enum VeilImportedFileAccessError: LocalizedError {
    case unsupportedExtension(expected: [String])
    case inaccessible
    case coordinationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let expected):
            return "文件类型不受支持，请选择：\(expected.joined(separator: "、"))。"
        case .inaccessible:
            return "无法读取所选文件。请确认文件已从 iCloud 或第三方文件提供商下载完成。"
        case .coordinationFailed(let detail):
            return "文件提供商没有完成导入：\(detail)"
        case .cancelled:
            return "已取消文件导入。"
        }
    }
}

/// Converts a short-lived security-scoped provider URL into an app-owned local
/// copy while the picker grant is still active. This also asks NSFileCoordinator
/// to download iCloud/third-party placeholders before the callback returns.
enum VeilImportedFileAccess {
    private static let stagingFolderName = "VeilLink-Import-Staging"
    private static let copyChunkBytes = 1_024 * 1_024

    /// Runs provider coordination and the potentially large local copy away from
    /// the SwiftUI callback. Cancellation is checked between chunks, so a 200 MiB
    /// backup or a large image does not monopolise the main thread.
    static func materializeInBackground(
        _ sourceURL: URL,
        acceptedExtensions: Set<String> = []
    ) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) {
            try materialize(sourceURL, acceptedExtensions: acceptedExtensions)
        }
        return try await withTaskCancellationHandler(
            operation: { try await worker.value },
            onCancel: { worker.cancel() }
        )
    }

    static func materialize(
        _ sourceURL: URL,
        acceptedExtensions: Set<String> = []
    ) throws -> URL {
        let normalizedExtensions = Set(acceptedExtensions.map { $0.lowercased() })
        if !normalizedExtensions.isEmpty,
           !normalizedExtensions.contains(sourceURL.pathExtension.lowercased()) {
            throw VeilImportedFileAccessError.unsupportedExtension(
                expected: normalizedExtensions.sorted()
            )
        }

        let granted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if granted { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(stagingFolderName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(sourceURL.lastPathComponent)

        var coordinationError: NSError?
        var copyError: Error?
        var copied = false
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [.withoutChanges],
            error: &coordinationError
        ) { readableURL in
            do {
                try copyCancellableFile(from: readableURL, to: destination)
                copied = true
            } catch is CancellationError {
                copyError = VeilImportedFileAccessError.cancelled
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            try? FileManager.default.removeItem(at: root)
            throw VeilImportedFileAccessError.coordinationFailed(
                coordinationError.localizedDescription
            )
        }
        if let copyError {
            try? FileManager.default.removeItem(at: root)
            throw copyError
        }
        guard copied, FileManager.default.isReadableFile(atPath: destination.path) else {
            try? FileManager.default.removeItem(at: root)
            throw VeilImportedFileAccessError.inaccessible
        }
        return destination
    }

    static func removeStagedCopy(_ url: URL) {
        // Only delete snapshots created below our canonical UUID lease root.
        try? VeilImportStagingLeasePolicy.removeOwnedCopy(url)
    }

    private static func copyCancellableFile(from source: URL, to destination: URL) throws {
        if Task.isCancelled { throw CancellationError() }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw VeilImportedFileAccessError.inaccessible
        }
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)
        defer {
            try? input.close()
            try? output.close()
        }

        while true {
            if Task.isCancelled { throw CancellationError() }
            let chunk = try input.read(upToCount: copyChunkBytes) ?? Data()
            if chunk.isEmpty { return }
            try output.write(contentsOf: chunk)
        }
    }
}
