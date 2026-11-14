import Foundation

/// App-owned, durable Files inbox. This is intentionally distinct from a
/// backup restore, a chat send, or loading a neural-network weight file.
struct VeilFileInboxRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let storedName: String
    let byteCount: Int64
    let sha256: String
    let importedAt: Date
    let kind: VeilFileInboxKind
}

enum VeilFileInboxKind: String, Codable, Sendable {
    case archive, numpy, image, text, html, pdf, boardTrainingCandidate, other

    var title: String {
        switch self {
        case .archive: return "ZIP 压缩包"
        case .numpy: return "NPZ 数值数据"
        case .image: return "图片"
        case .text: return "文本 / 数据"
        case .html: return "HTML 资料"
        case .pdf: return "PDF 文档"
        case .boardTrainingCandidate: return "VeilLink 训练包候选"
        case .other: return "通用文件"
        }
    }

    static func detect(filename: String) -> Self {
        let lower = filename.lowercased()
        if lower.hasSuffix(".vltrain.json") { return .boardTrainingCandidate }
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "zip": return .archive
        case "npz": return .numpy
        case "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff", "bmp": return .image
        case "txt", "md", "csv", "json", "log", "xml", "yaml", "yml": return .text
        case "html", "htm": return .html
        case "pdf": return .pdf
        default: return .other
        }
    }
}

enum VeilFileInboxError: LocalizedError {
    case notStaged
    case oversized
    case notRegularFile
    case corruptedCopy
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .notStaged: return "文件尚未通过系统 Files 安全导入，请重新选择原文件。"
        case .oversized: return "单文件导入上限为 512 MiB，原文件未修改。"
        case .notRegularFile: return "只能导入普通文件，不能导入文件夹或链接。"
        case .corruptedCopy: return "存储前后 SHA-256 校验不一致，未保存这份副本。"
        case .invalidRecord: return "本机导入记录不完整或已失效。"
        }
    }
}

/// A complete import is published only after local copy + length + SHA-256
/// verification and an atomic directory rename. Interrupted imports are not
/// visible as completed records. Provider files are never moved or altered.
enum VeilFileInbox {
    static let maximumFileBytes: Int64 = 512 * 1_024 * 1_024
    private static let manifestName = "record.json"

    static func defaultRoot(fileManager: FileManager = .default) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("VeilLink", isDirectory: true)
            .appendingPathComponent("FileInbox", isDirectory: true)
    }

    static func importStaged(
        _ stagedURL: URL,
        root: URL = defaultRoot(),
        maximumBytes: Int64 = maximumFileBytes,
        fileManager: FileManager = .default
    ) throws -> VeilFileInboxRecord {
        guard VeilImportStagingLeasePolicy.owns(stagedURL) else {
            throw VeilFileInboxError.notStaged
        }
        let values = try stagedURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw VeilFileInboxError.notRegularFile
        }
        guard maximumBytes > 0, let sourceSize = values.fileSize,
              sourceSize >= 0, Int64(sourceSize) <= maximumBytes else {
            throw VeilFileInboxError.oversized
        }

        let id = UUID()
        let originalName = stagedURL.lastPathComponent
        let cleanExtension = stagedURL.pathExtension.lowercased()
        let isSafeExtension = (1...16).contains(cleanExtension.utf8.count)
            && cleanExtension.utf8.allSatisfy { byte in
                (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
            }
        let storedName = MediaTransferPolicy.safeGenericFilename(originalName)
            ?? (isSafeExtension ? "content." + cleanExtension : "content.bin")
        let pending = root.appendingPathComponent(".pending-" + id.uuidString, isDirectory: true)
        let published = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: pending, withIntermediateDirectories: false)
        var didPublish = false
        defer {
            if !didPublish { try? fileManager.removeItem(at: pending) }
        }

        let destination = pending.appendingPathComponent(storedName)
        try fileManager.copyItem(at: stagedURL, to: destination)
        let sourceIntegrity = try VeilFileIntegrityEngine.inspect(url: stagedURL)
        let storedIntegrity = try VeilFileIntegrityEngine.inspect(url: destination)
        guard sourceIntegrity.byteCount == storedIntegrity.byteCount,
              sourceIntegrity.sha256 == storedIntegrity.sha256,
              sourceIntegrity.byteCount == Int64(sourceSize) else {
            throw VeilFileInboxError.corruptedCopy
        }
        try Task.checkCancellation()

        let record = VeilFileInboxRecord(
            id: id,
            displayName: String(originalName.prefix(240)),
            storedName: storedName,
            byteCount: storedIntegrity.byteCount,
            sha256: storedIntegrity.sha256,
            importedAt: Date(),
            kind: VeilFileInboxKind.detect(filename: originalName)
        )
        let encoder = JSONEncoder()
        let metadata = try encoder.encode(record)
        try metadata.write(to: pending.appendingPathComponent(manifestName), options: .atomic)
        try fileManager.moveItem(at: pending, to: published)
        didPublish = true
        return record
    }

    static func list(root: URL = defaultRoot(), fileManager: FileManager = .default) throws -> [VeilFileInboxRecord] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let folders = try fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: []
        )
        return folders.compactMap { folder in
            guard UUID(uuidString: folder.lastPathComponent) != nil else { return nil }
            return try? readRecord(in: folder)
        }.sorted { $0.importedAt > $1.importedAt }
    }

    static func fileURL(
        for record: VeilFileInboxRecord,
        root: URL = defaultRoot()
    ) throws -> URL {
        let folder = root.appendingPathComponent(record.id.uuidString, isDirectory: true)
        guard try readRecord(in: folder) == record else { throw VeilFileInboxError.invalidRecord }
        return folder.appendingPathComponent(record.storedName)
    }

    static func verify(
        _ record: VeilFileInboxRecord,
        root: URL = defaultRoot()
    ) throws -> Bool {
        let url = try fileURL(for: record, root: root)
        let actual = try VeilFileIntegrityEngine.inspect(url: url)
        return actual.byteCount == record.byteCount && actual.sha256 == record.sha256
    }

    static func remove(
        _ record: VeilFileInboxRecord,
        root: URL = defaultRoot(),
        fileManager: FileManager = .default
    ) throws {
        let folder = root.appendingPathComponent(record.id.uuidString, isDirectory: true)
        guard try readRecord(in: folder) == record else { throw VeilFileInboxError.invalidRecord }
        try fileManager.removeItem(at: folder)
    }

    private static func readRecord(in folder: URL) throws -> VeilFileInboxRecord {
        let directory = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard directory.isDirectory == true, directory.isSymbolicLink != true,
              let id = UUID(uuidString: folder.lastPathComponent) else {
            throw VeilFileInboxError.invalidRecord
        }
        let metadataURL = folder.appendingPathComponent(manifestName)
        let data = try Data(contentsOf: metadataURL)
        let record = try JSONDecoder().decode(VeilFileInboxRecord.self, from: data)
        guard record.id == id, record.byteCount >= 0, record.byteCount <= maximumFileBytes,
              record.sha256.count == 64,
              MediaTransferPolicy.safeGenericFilename(record.storedName) == record.storedName else {
            throw VeilFileInboxError.invalidRecord
        }
        let file = folder.appendingPathComponent(record.storedName)
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.fileSize.map(Int64.init) == record.byteCount else {
            throw VeilFileInboxError.invalidRecord
        }
        return record
    }
}
