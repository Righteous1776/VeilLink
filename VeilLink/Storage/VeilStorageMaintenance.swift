import Foundation

enum VeilStorageCategory: String, CaseIterable, Hashable, Sendable {
    case runtimeCache
    case diagnostics
    case staleTemporaryExports
    case downloads
    case backupExports
    case protectedData

    var title: String {
        switch self {
        case .runtimeCache: return "运行缓存"
        case .diagnostics: return "诊断与黑匣子"
        case .staleTemporaryExports: return "过期临时文件"
        case .downloads: return "已下载内容"
        case .backupExports: return "已导出的备份"
        case .protectedData: return "受保护数据"
        }
    }

    var isDeletable: Bool { self != .protectedData }
    var isRecommended: Bool {
        self == .runtimeCache || self == .diagnostics || self == .staleTemporaryExports
    }
}

struct VeilStorageCategorySnapshot: Identifiable, Equatable, Sendable {
    var id: VeilStorageCategory { category }
    let category: VeilStorageCategory
    let byteCount: Int64
    let itemCount: Int
    let detail: String
}

struct VeilStorageLargeItem: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let byteCount: Int64
    let category: VeilStorageCategory
}

struct VeilStorageSnapshot: Equatable, Sendable {
    let categories: [VeilStorageCategorySnapshot]
    let largeItems: [VeilStorageLargeItem]
    let scannedAt: Date

    var reclaimableBytes: Int64 {
        categories.filter { $0.category.isDeletable }.reduce(0) { $0 + $1.byteCount }
    }
}

struct VeilStorageCleanupResult: Equatable, Sendable {
    let removedBytes: Int64
    let removedItems: Int
    let failures: [String]
}

struct VeilStorageRoots: Sendable {
    let appSupport: URL
    let downloads: URL
    let diagnostics: URL
    let documents: URL
    let temporary: URL

    static func live(fileManager: FileManager = .default) -> VeilStorageRoots {
        let support = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory).appendingPathComponent("VeilLink", isDirectory: true)
        return VeilStorageRoots(
            appSupport: support,
            downloads: support.appendingPathComponent("Downloads", isDirectory: true),
            diagnostics: support.appendingPathComponent("Diagnostics", isDirectory: true),
            documents: fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? support.appendingPathComponent("Exports", isDirectory: true),
            temporary: fileManager.temporaryDirectory
        )
    }
}

/// Scans and removes only allow-listed, reproducible storage. Chat attachments, SQLite files,
/// identity material and Keychain state are never cleanup candidates.
actor VeilStorageMaintenance {
    static let staleTemporaryAge: TimeInterval = 24 * 60 * 60

    private let roots: VeilStorageRoots
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    init(
        roots: VeilStorageRoots = .live(),
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.roots = roots
        self.fileManager = fileManager
        self.now = now
    }

    func scan() -> VeilStorageSnapshot {
        let downloadItems = directChildren(of: roots.downloads)
        let backupItems = directChildren(of: roots.documents).filter(isVeilLinkBackup)
        let temporaryItems = directChildren(of: roots.temporary).filter(isStaleTemporaryArtifact)
        let diagnosticItems = directChildren(of: roots.diagnostics)

        let downloads = aggregate(downloadItems)
        let backups = aggregate(backupItems)
        let temporary = aggregate(temporaryItems)
        let diagnostics = aggregate(diagnosticItems)
        let protected = protectedUsage()
        let urlCacheBytes = Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)

        let categories = [
            VeilStorageCategorySnapshot(category: .runtimeCache, byteCount: urlCacheBytes, itemCount: urlCacheBytes > 0 ? 1 : 0, detail: "网络响应与内存预览；会按需重建"),
            VeilStorageCategorySnapshot(category: .diagnostics, byteCount: diagnostics.bytes, itemCount: diagnostics.count, detail: "运行日志、压力测试与黑匣子附件"),
            VeilStorageCategorySnapshot(category: .staleTemporaryExports, byteCount: temporary.bytes, itemCount: temporary.count, detail: "超过 24 小时的 VeilLink 临时导出"),
            VeilStorageCategorySnapshot(category: .downloads, byteCount: downloads.bytes, itemCount: downloads.count, detail: "专用下载区；删除后可能需要重新获取"),
            VeilStorageCategorySnapshot(category: .backupExports, byteCount: backups.bytes, itemCount: backups.count, detail: "Documents 中的 VeilLink 加密 ZIP"),
            VeilStorageCategorySnapshot(category: .protectedData, byteCount: protected.bytes, itemCount: protected.count, detail: "聊天、附件、数据库与身份状态；永不参与清理")
        ]

        let recoverable = downloadItems.map { ($0, VeilStorageCategory.downloads) }
            + backupItems.map { ($0, VeilStorageCategory.backupExports) }
            + temporaryItems.map { ($0, VeilStorageCategory.staleTemporaryExports) }
        let largeItems = recoverable.compactMap { url, category -> VeilStorageLargeItem? in
            let summary = aggregate([url])
            guard summary.bytes > 0 else { return nil }
            return VeilStorageLargeItem(
                id: "\(category.rawValue):\(url.lastPathComponent)",
                displayName: url.lastPathComponent,
                byteCount: summary.bytes,
                category: category
            )
        }
        .sorted { $0.byteCount > $1.byteCount }
        .prefix(8)

        return VeilStorageSnapshot(categories: categories, largeItems: Array(largeItems), scannedAt: now())
    }

    func clean(_ categories: Set<VeilStorageCategory>) -> VeilStorageCleanupResult {
        var candidates: [(URL, VeilStorageCategory)] = []
        if categories.contains(.downloads) {
            candidates += directChildren(of: roots.downloads).map { ($0, .downloads) }
        }
        if categories.contains(.backupExports) {
            candidates += directChildren(of: roots.documents).filter(isVeilLinkBackup).map { ($0, .backupExports) }
        }
        if categories.contains(.staleTemporaryExports) {
            candidates += directChildren(of: roots.temporary).filter(isStaleTemporaryArtifact).map { ($0, .staleTemporaryExports) }
        }

        var bytes: Int64 = 0
        var removed = 0
        var failures: [String] = []
        for (url, category) in candidates {
            guard isAllowed(url, for: category) else {
                failures.append("拒绝越界项目：\(url.lastPathComponent)")
                continue
            }
            let size = aggregate([url]).bytes
            do {
                try fileManager.removeItem(at: url)
                bytes += size
                removed += 1
            } catch {
                failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        if categories.contains(.runtimeCache) {
            URLCache.shared.removeAllCachedResponses()
        }
        return VeilStorageCleanupResult(removedBytes: bytes, removedItems: removed, failures: failures)
    }

    private func directChildren(of root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        return (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private func aggregate(_ urls: [URL]) -> (bytes: Int64, count: Int) {
        var bytes: Int64 = 0
        var count = 0
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            if values?.isSymbolicLink == true { continue }
            if values?.isRegularFile == true {
                bytes += Int64(values?.fileSize ?? 0)
                count += 1
                continue
            }
            guard values?.isDirectory == true,
                  let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }
            for case let child as URL in enumerator {
                let childValues = try? child.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
                if childValues?.isSymbolicLink == true {
                    if childValues?.isDirectory == true { enumerator.skipDescendants() }
                    continue
                }
                if childValues?.isRegularFile == true {
                    bytes += Int64(childValues?.fileSize ?? 0)
                    count += 1
                }
            }
        }
        return (bytes, count)
    }

    private func protectedUsage() -> (bytes: Int64, count: Int) {
        let excluded = [roots.downloads.standardizedFileURL, roots.diagnostics.standardizedFileURL]
        let children = directChildren(of: roots.appSupport).filter { child in
            !excluded.contains(child.standardizedFileURL)
        }
        return aggregate(children)
    }

    private func isVeilLinkBackup(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values?.isRegularFile == true
            && values?.isSymbolicLink != true
            && name.hasPrefix("VeilLink-")
            && name.lowercased().hasSuffix(".zip")
    }

    private func isStaleTemporaryArtifact(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        let prefixes = ["VeilLink-DeepTelemetry-", "VeilLink-Export-", "VeilLink-Restore-", "VeilVoice-", "VeilLink-Image-"]
        guard prefixes.contains(where: name.hasPrefix) else { return false }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isSymbolicLinkKey])
        guard values?.isSymbolicLink != true, let modified = values?.contentModificationDate else { return false }
        return now().timeIntervalSince(modified) >= Self.staleTemporaryAge
    }

    private func isAllowed(_ url: URL, for category: VeilStorageCategory) -> Bool {
        let parent = url.deletingLastPathComponent().standardizedFileURL
        switch category {
        case .downloads:
            return parent == roots.downloads.standardizedFileURL
        case .backupExports:
            return parent == roots.documents.standardizedFileURL && isVeilLinkBackup(url)
        case .staleTemporaryExports:
            return parent == roots.temporary.standardizedFileURL && isStaleTemporaryArtifact(url)
        default:
            return false
        }
    }
}
