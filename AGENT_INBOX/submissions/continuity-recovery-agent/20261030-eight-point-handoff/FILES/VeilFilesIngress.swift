import Foundation

/// Unified read boundary for the Files app, including security-scoped
/// and File Provider documents. A picker URL must not escape withRead's closure.
enum VeilFilesIngress {
    enum Failure: Error, LocalizedError {
        case notFile, notRegularFile, notReadable, tooLarge, noCoordinatedURL
        var errorDescription: String? {
            switch self {
            case .notFile: return "请选择“文件”中的普通文件，而不是文件夹或远程链接。"
            case .notRegularFile: return "所选项目不是普通文件，或是符号链接。"
            case .notReadable: return "无法读取文件，请在“文件”中确认已下载且具有访问权限。"
            case .tooLarge: return "文件超过当前操作允许的大小。"
            case .noCoordinatedURL: return "文件提供者没有返回可读内容，请重新选择。"
            }
        }
    }

    static func withRead<T>(from source: URL, maximumBytes: Int64, _ body: (URL) throws -> T) throws -> T {
        guard source.isFileURL else { throw Failure.notFile }
        guard maximumBytes > 0 else { throw Failure.tooLarge }
        #if canImport(Darwin)
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatedError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinatedError) { readable in
            result = Result {
                try ensureReadable(readable, maximumBytes: maximumBytes)
                return try body(readable)
            }
        }
        if let coordinatedError { throw coordinatedError }
        guard let result else { throw Failure.noCoordinatedURL }
        return try result.get()
        #else
        try ensureReadable(source, maximumBytes: maximumBytes)
        return try body(source)
        #endif
    }

    /// An owned temporary snapshot, used when a picker callback must end
    /// before a password sheet or asynchronous image conversion finishes.
    /// Caller must later call discard(_:) on every success/cancel/error path.
    static func stage(from source: URL, maximumBytes: Int64) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLink-FilesIngress-\(UUID().uuidString)")
            .appendingPathExtension(source.pathExtension.isEmpty ? "data" : source.pathExtension)
        do {
            try withRead(from: source, maximumBytes: maximumBytes) { readable in
                try FileManager.default.copyItem(at: readable, to: destination)
                try ensureReadable(destination, maximumBytes: maximumBytes)
            }
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    static func discard(_ staged: URL) {
        guard staged.isFileURL,
              staged.deletingLastPathComponent().standardizedFileURL ==
                FileManager.default.temporaryDirectory.standardizedFileURL,
              staged.deletingPathExtension().lastPathComponent.hasPrefix("VeilLink-FilesIngress-")
        else { return }
        try? FileManager.default.removeItem(at: staged)
    }

    private static func ensureReadable(_ url: URL, maximumBytes: Int64) throws {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else {
            throw Failure.notReadable
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Failure.notRegularFile
        }
        guard let size = values.fileSize, size >= 0, Int64(size) <= maximumBytes else {
            throw Failure.tooLarge
        }
    }
}
