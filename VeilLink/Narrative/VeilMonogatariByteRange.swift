import Foundation

/// RFC 7233 single-byte-range subset for a read-only local bundle server.
/// Deliberately rejects multiple/ambiguous ranges rather than guessing.
struct VeilNovelResolvedByteRange: Equatable {
    let first: Int
    let last: Int    // inclusive
    let fullLength: Int

    var count: Int { last - first + 1 }
    var contentRange: String { "bytes \(first)-\(last)/\(fullLength)" }
}

enum VeilNovelRangeParser {
    static func resolve(_ header: String?, fileLength: Int) -> VeilNovelResolvedByteRange? {
        guard fileLength > 0 else { return nil }
        guard let header = header else {
            return VeilNovelResolvedByteRange(first: 0, last: fileLength - 1, fullLength: fileLength)
        }
        let value = header.trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("bytes="), !value.contains(",") else { return nil }
        let spec = String(value.dropFirst(6))
        let parts = spec.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        func digits(_ s: Substring) -> Int? {
            guard !s.isEmpty, s.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
            return Int(s)
        }
        if parts[0].isEmpty {
            guard let suffix = digits(parts[1]), suffix > 0 else { return nil }
            return VeilNovelResolvedByteRange(first: max(0, fileLength - suffix), last: fileLength - 1, fullLength: fileLength)
        }
        guard let first = digits(parts[0]), first < fileLength else { return nil }
        let end: Int
        if parts[1].isEmpty { end = fileLength - 1 }
        else {
            guard let explicit = digits(parts[1]), explicit >= first else { return nil }
            end = min(explicit, fileLength - 1)
        }
        return VeilNovelResolvedByteRange(first: first, last: end, fullLength: fileLength)
    }
}
