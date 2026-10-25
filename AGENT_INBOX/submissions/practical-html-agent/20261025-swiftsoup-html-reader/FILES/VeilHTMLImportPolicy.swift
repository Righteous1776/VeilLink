import Foundation

/// Offline-import limits for a resource-constrained iOS 15 device. No network I/O.
enum VeilHTMLImportPolicy {
    static let maximumSourceBytes = 512 * 1024
    static let maximumOutputCharacters = 100_000
    static let maximumLinks = 40
    static let maximumSections = 400
    static let maximumSearchResults = 100

    static func decode(_ data: Data) throws -> String {
        guard !data.isEmpty else { throw VeilHTMLImportError.emptyFile }
        guard data.count <= maximumSourceBytes else { throw VeilHTMLImportError.fileTooLarge }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            guard let result = String(data: data.dropFirst(3), encoding: .utf8) else {
                throw VeilHTMLImportError.unsupportedEncoding
            }
            return result
        }
        if data.starts(with: [0xFF, 0xFE]) {
            guard let value = String(data: data, encoding: .utf16LittleEndian) else {
                throw VeilHTMLImportError.unsupportedEncoding
            }
            return value.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        if data.starts(with: [0xFE, 0xFF]) {
            guard let value = String(data: data, encoding: .utf16BigEndian) else {
                throw VeilHTMLImportError.unsupportedEncoding
            }
            return value.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw VeilHTMLImportError.unsupportedEncoding
        }
        return decoded
    }

    /// Only classify human-readable web links; never open or fetch them automatically.
    static func safeExternalLink(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 2048, !value.isEmpty,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let parts = URLComponents(string: value),
              let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else { return nil }
        return value
    }

    static func bounded(_ text: String, limit: Int = maximumOutputCharacters) -> String {
        guard limit > 0 else { return "" }
        return String(text.prefix(limit))
    }

    static func isMatch(_ line: String, query: String) -> Bool {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || line.localizedCaseInsensitiveContains(cleaned)
    }
}

enum VeilHTMLImportError: Error, LocalizedError, Sendable {
    case emptyFile
    case fileTooLarge
    case unsupportedEncoding
    case invalidDocument
    case unsupportedSource

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "文件为空。"
        case .fileTooLarge: return "HTML 文件超过 512 KiB；请先在其他工具中精简后导入。"
        case .unsupportedEncoding: return "目前支持 UTF-8 和带 BOM 的 UTF-16 HTML。"
        case .invalidDocument: return "无法从这个 HTML 文件提取正文。"
        case .unsupportedSource: return "只接受来自系统文件选择器的本地文件。"
        }
    }
}

struct VeilOfflineHTMLLink: Equatable, Sendable, Identifiable {
    let label: String
    let address: String
    var id: String { address }
}

struct VeilOfflineHTMLDocument: Sendable, Equatable {
    let title: String
    let sections: [String]
    let links: [VeilOfflineHTMLLink]
    let truncated: Bool

    func matchingSections(query: String) -> [String] {
        Array(sections.lazy.filter { VeilHTMLImportPolicy.isMatch($0, query: query) }
            .prefix(VeilHTMLImportPolicy.maximumSearchResults))
    }
}
