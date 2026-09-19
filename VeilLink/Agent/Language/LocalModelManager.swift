import CryptoKit
import Foundation

struct LocalModelValidation: Equatable, Sendable {
    let url: URL
    let byteCount: Int64
    let sha256: String
}

enum LocalModelError: LocalizedError, Equatable {
    case missing(String)
    case tooSmall(Int64)
    case hashMismatch(expected: String, actual: String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "本地模型未安装：\(name)。"
        case .tooSmall:
            return "本地模型文件不完整。"
        case .hashMismatch:
            return "本地模型完整性校验失败。"
        case .unreadable:
            return "无法读取本地模型文件。"
        }
    }
}

private actor LocalModelValidationCache {
    private var values: [String: LocalModelValidation] = [:]

    func value(for id: String, url: URL) -> LocalModelValidation? {
        guard let value = values[id], value.url == url else { return nil }
        return value
    }

    func store(_ value: LocalModelValidation, for id: String) {
        values[id] = value
    }

    func clear() {
        values.removeAll(keepingCapacity: false)
    }
}

enum LocalModelManager {
    private static let cache = LocalModelValidationCache()
    static func bundledURL(for descriptor: LocalModelDescriptor, bundle: Bundle = .main) throws -> URL {
        var candidates = [bundle]
        candidates.append(contentsOf: Bundle.allBundles)
        candidates.append(contentsOf: Bundle.allFrameworks)

        var seen = Set<ObjectIdentifier>()
        for candidate in candidates where seen.insert(ObjectIdentifier(candidate)).inserted {
            if let url = candidate.url(forResource: descriptor.resourceName, withExtension: descriptor.fileExtension) {
                return url
            }
            if let url = candidate.url(
                forResource: descriptor.resourceName,
                withExtension: descriptor.fileExtension,
                subdirectory: "Models"
            ) {
                return url
            }
        }
        throw LocalModelError.missing("\(descriptor.resourceName).\(descriptor.fileExtension)")
    }

    static func validate(
        descriptor: LocalModelDescriptor,
        bundle: Bundle = .main
    ) async throws -> LocalModelValidation {
        let url = try bundledURL(for: descriptor, bundle: bundle)
        if let cached = await cache.value(for: descriptor.id, url: url) {
            return cached
        }

        let expectedHash = descriptor.sha256.lowercased()
        let minimumBytes = descriptor.expectedMinimumBytes

        let validation = try await Task.detached(priority: .utility) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { throw LocalModelError.unreadable }
            let byteCount = Int64(values.fileSize ?? 0)
            guard byteCount >= minimumBytes else { throw LocalModelError.tooSmall(byteCount) }

            let actualHash = try sha256(url: url)
            guard actualHash == expectedHash else {
                throw LocalModelError.hashMismatch(expected: expectedHash, actual: actualHash)
            }
            return LocalModelValidation(url: url, byteCount: byteCount, sha256: actualHash)
        }.value
        await cache.store(validation, for: descriptor.id)
        return validation
    }

    static func clearProcessValidationCache() async {
        await cache.clear()
    }

    private nonisolated static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 2 * 1_024 * 1_024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
