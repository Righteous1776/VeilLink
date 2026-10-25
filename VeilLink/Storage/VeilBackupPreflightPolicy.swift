import Foundation

/// Read-only metadata policy for existing VeilLink ZIP backup format v1/v2.
/// The inspector owns ZIPFoundation I/O; this policy never reads or writes files.
enum VeilBackupPreflightPolicy {
    static let maxArchiveBytes: UInt64 = 200 * 1024 * 1024
    static let maxExpandedBytes: UInt64 = 350 * 1024 * 1024
    static let maxEntryCount = 10_000
    static let maxNameBytes = 1024
    static let maxManifestBytes: UInt64 = 128 * 1024
    static let maxExpansionRatio: UInt64 = 1_500
    static let expansionCheckFloor: UInt64 = 1 * 1024 * 1024
    static let requiredFiles: Set<String> = ["manifest.json", "database.enc", "storage-key.enc", "identity.enc"]

    enum Kind: String, Sendable { case file, directory, symlink, other }

    struct EntryInfo: Equatable, Sendable {
        let path: String
        let kind: Kind
        let compressedBytes: UInt64
        let expandedBytes: UInt64
    }

    enum Problem: String, CaseIterable, Sendable {
        case emptyArchive, archiveTooLarge, tooManyEntries, tooLargeExpanded
        case unsafePath, disallowedPath, duplicatePath, symlink, oversizedName
        case implausibleCompression, missingRequiredFile, invalidEntrySize
        case damagedArchive, invalidManifest, crcMismatch

        var explanation: String {
            switch self {
            case .emptyArchive: return "归档为空或不是有效 ZIP。"
            case .archiveTooLarge: return "归档体积超过 VeilLink 当前 200 MiB 导入上限。"
            case .tooManyEntries: return "ZIP 条目数超过 10,000。"
            case .tooLargeExpanded: return "声明的总解压体积超过 350 MiB。"
            case .unsafePath: return "检测到危险的归档路径或路径分隔符。"
            case .disallowedPath: return "包含现有备份格式不支持的文件或目录。"
            case .duplicatePath: return "检测到重复条目或路径大小写／Unicode 碰撞。"
            case .symlink: return "ZIP 包含符号链接或未知文件类型。"
            case .oversizedName: return "某条目名称超过 1,024 UTF-8 字节。"
            case .implausibleCompression: return "发现异常压缩比，可能导致解压资源耗尽。"
            case .missingRequiredFile: return "缺少 manifest.json 或加密数据库、存储密钥、身份文件。"
            case .invalidEntrySize: return "发现不合理或溢出的文件大小。"
            case .damagedArchive: return "ZIP 文件结构损坏，无法打开或读取。"
            case .invalidManifest: return "备份清单损坏或版本不在现有支持范围内。"
            case .crcMismatch: return "归档条目 CRC 不匹配或读取失败。"
            }
        }
    }

    struct Report: Equatable, Sendable {
        let zipBytes: UInt64
        let compressedContentBytes: UInt64
        let expandedBytes: UInt64
        let entries: Int
        let attachments: Int
        let problems: [Problem]
        let crcVerified: Bool
        let version: Int?
        let createdAt: Date?

        var permittedToRestore: Bool { problems.isEmpty }
        var safetyLabel: String {
            if !permittedToRestore { return "检查未通过：请勿直接恢复" }
            return crcVerified ? "结构与 CRC 已核对：仍需密码和数据库验证" : "结构预检通过：内容 CRC 尚未逐项验证"
        }
        func appending(_ newProblems: [Problem], crcVerified: Bool? = nil,
                       version: Int? = nil, createdAt: Date? = nil) -> Report {
            var merged = problems
            for p in newProblems where !merged.contains(p) { merged.append(p) }
            return .init(zipBytes: zipBytes, compressedContentBytes: compressedContentBytes,
                         expandedBytes: expandedBytes, entries: entries, attachments: attachments,
                         problems: merged, crcVerified: crcVerified ?? self.crcVerified,
                         version: version ?? self.version, createdAt: createdAt ?? self.createdAt)
        }
    }

    /// Path allowlist must stay compatible with BackupManager's current v1/v2 layout.
    static func isAllowedPath(_ name: String, kind: Kind) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.hasPrefix("\\"),
              !name.contains("\\"), !name.contains(":"), !name.contains("\0"),
              name == name.precomposedStringWithCanonicalMapping else { return false }
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." &&
                  !$0.hasSuffix(" ") && !$0.hasSuffix(".") &&
                  !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) ||
              (kind == .directory && name == "attachments/") else { return false }
        if kind == .directory { return name == "attachments/" }
        guard kind == .file else { return false }
        if requiredFiles.contains(name) { return true }
        guard components.count == 2, components[0] == "attachments",
              components[1].hasSuffix(".bin") else { return false }
        let stem = String(components[1].dropLast(4))
        return UUID(uuidString: stem) != nil
    }

    /// Reject case/normalization aliases even if the user's file system is case sensitive.
    static func collisionKey(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func evaluate(_ entries: [EntryInfo], zipBytes: UInt64) -> Report {
        var problems: [Problem] = []
        func flag(_ p: Problem) { if !problems.contains(p) { problems.append(p) } }
        if zipBytes == 0 || entries.isEmpty { flag(.emptyArchive) }
        if zipBytes > maxArchiveBytes { flag(.archiveTooLarge) }
        if entries.count > maxEntryCount { flag(.tooManyEntries) }

        var seen: Set<String> = []
        var files: Set<String> = []
        var totalExpanded: UInt64 = 0
        var totalCompressed: UInt64 = 0
        var attachments = 0
        for entry in entries.prefix(maxEntryCount + 1) {
            if entry.kind == .symlink || entry.kind == .other { flag(.symlink) }
            if entry.path.utf8.count > maxNameBytes { flag(.oversizedName) }
            guard isAllowedPath(entry.path, kind: entry.kind) else {
                flag(entry.path.contains("..") || entry.path.contains("\\") || entry.path.hasPrefix("/") ? .unsafePath : .disallowedPath)
                continue
            }
            if !seen.insert(collisionKey(entry.path)).inserted { flag(.duplicatePath) }
            if entry.kind == .directory { continue }
            files.insert(entry.path)
            if entry.path.hasPrefix("attachments/") { attachments += 1 }
            let (e, eOverflow) = totalExpanded.addingReportingOverflow(entry.expandedBytes)
            let (c, cOverflow) = totalCompressed.addingReportingOverflow(entry.compressedBytes)
            if eOverflow || cOverflow { flag(.invalidEntrySize) }
            else {
                totalExpanded = e
                totalCompressed = c
                if totalExpanded > maxExpandedBytes { flag(.tooLargeExpanded) }
            }
            if entry.expandedBytes > 0 && entry.compressedBytes == 0 {
                flag(.implausibleCompression)
            } else if entry.expandedBytes >= expansionCheckFloor,
                      entry.compressedBytes > 0,
                      entry.expandedBytes / entry.compressedBytes > maxExpansionRatio {
                flag(.implausibleCompression)
            }
        }
        if totalCompressed > zipBytes { flag(.invalidEntrySize) }
        if !requiredFiles.isSubset(of: files) { flag(.missingRequiredFile) }
        return .init(zipBytes: zipBytes, compressedContentBytes: totalCompressed,
                     expandedBytes: totalExpanded, entries: entries.count,
                     attachments: attachments, problems: problems,
                     crcVerified: false, version: nil, createdAt: nil)
    }
}
