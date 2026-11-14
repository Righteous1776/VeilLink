import Foundation

enum VeilImportedFileAccessError: LocalizedError {
    case unsupportedExtension(expected: [String])
    case inaccessible
    case coordinationFailed(String)
    case cancelled
    case tooLarge(maximumBytes: Int)
    case chatFileUnsupported
    case chatTextTooLarge
    case chatTextInvalid

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
        case .tooLarge(let maximumBytes):
            return "文件超过此项导入大小上限（\(maximumBytes) 字节）。"
        case .chatFileUnsupported:
            return "文件已选取，但当前聊天仅支持图片发送及 TXT、MD、JSON、CSV 文本导入草稿；PDF、ZIP 等二进制文件发送需另行升级通信协议。"
        case .chatTextTooLarge:
            return "文本文件超过当前聊天的 16 KB 消息限制；未导入草稿。"
        case .chatTextInvalid:
            return "文件不是有效的 UTF-8 文本，或包含二进制内容；未导入草稿。"
        }
    }
}

/// Converts a short-lived security-scoped provider URL into an app-owned local
/// copy while the picker grant is still active. This also asks NSFileCoordinator
/// to download iCloud/third-party placeholders before the callback returns.
enum VeilImportedFileAccess {
    private static let stagingFolderName = "VeilLink-Import-Staging"
    private static let chatTextExtensions: Set<String> = ["txt", "md", "json", "csv"]
    static let maximumChatDraftBytes = 16_384

    /// Converts a trusted *app-owned* Files staging snapshot into a user-confirmed draft.
    /// No arbitrary file bytes are routed into the v4 image/voice attachment lane.
    static func chatDraftText(from stagedURL: URL) throws -> String {
        guard VeilImportStagingLeasePolicy.owns(stagedURL) else {
            throw VeilImportedFileAccessError.inaccessible
        }
        guard chatTextExtensions.contains(stagedURL.pathExtension.lowercased()) else {
            throw VeilImportedFileAccessError.chatFileUnsupported
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: stagedURL.path)
        guard let count = (attributes[.size] as? NSNumber)?.intValue,
              count > 0, count <= maximumChatDraftBytes else {
            throw VeilImportedFileAccessError.chatTextTooLarge
        }
        let data = try Data(contentsOf: stagedURL)
        guard data.count <= maximumChatDraftBytes, !data.isEmpty else {
            throw VeilImportedFileAccessError.chatTextTooLarge
        }
        guard let text = String(data: data, encoding: .utf8),
              !text.contains("\u{0000}"),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VeilImportedFileAccessError.chatTextInvalid
        }
        return text
    }
    private static let copyChunkBytes = 1_024 * 1_024

    /// Runs provider coordination and the potentially large local copy away from
    /// the SwiftUI callback. Cancellation is checked between chunks, so a 200 MiB
    /// backup or a large image does not monopolise the main thread.
    static func materializeInBackground(
        _ sourceURL: URL,
        acceptedExtensions: Set<String> = [],
        maximumBytes: Int? = nil
    ) async throws -> URL {
        // Acquire the provider grant before hopping to the detached copying
        // executor. A Files picker may begin dismissal immediately after its
        // completion handler returns. The outer scope stays live until all
        // coordination/copy work has actually finished.
        let outerGrant = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if outerGrant { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let worker = Task.detached(priority: .userInitiated) {
            try materialize(sourceURL, acceptedExtensions: acceptedExtensions, maximumBytes: maximumBytes)
        }
        return try await withTaskCancellationHandler(
            operation: { try await worker.value },
            onCancel: { worker.cancel() }
        )
    }

    static func materialize(
        _ sourceURL: URL,
        acceptedExtensions: Set<String> = [],
        maximumBytes: Int? = nil
    ) throws -> URL {
        if let maximumBytes, maximumBytes < 0 {
            throw VeilImportedFileAccessError.tooLarge(maximumBytes: maximumBytes)
        }
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
                try copyCancellableFile(from: readableURL, to: destination, maximumBytes: maximumBytes)
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

    private static func copyCancellableFile(from source: URL, to destination: URL, maximumBytes: Int?) throws {
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

        var copiedBytes = 0
        while true {
            if Task.isCancelled { throw CancellationError() }
            let chunk = try input.read(upToCount: copyChunkBytes) ?? Data()
            if chunk.isEmpty { return }
            if let maximumBytes, chunk.count > maximumBytes - copiedBytes {
                throw VeilImportedFileAccessError.tooLarge(maximumBytes: maximumBytes)
            }
            copiedBytes += chunk.count
            try output.write(contentsOf: chunk)
        }
    }
}
