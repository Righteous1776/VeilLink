import CryptoKit
import Foundation

struct VeilFileIntegrityResult: Equatable, Sendable {
    let fileName: String
    let byteCount: Int64
    let sha256: String
}

enum VeilFileIntegrityComparison: Equatable, Sendable {
    case identical
    case different
}

enum VeilFileIntegrityError: LocalizedError, Equatable {
    case notRegularFile
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notRegularFile:
            return "请选择普通文件，而不是文件夹或特殊项目。"
        case .unreadable:
            return "无法读取所选文件。请确认文件已下载到本机后重试。"
        }
    }
}

enum VeilFileIntegrityEngine {
    static let readChunkBytes = 512 * 1_024

    static func inspect(url: URL) throws -> VeilFileIntegrityResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                throw VeilFileIntegrityError.notRegularFile
            }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            var hasher = SHA256()
            var byteCount: Int64 = 0
            while true {
                try Task.checkCancellation()
                let data = try handle.read(upToCount: readChunkBytes) ?? Data()
                if data.isEmpty { break }
                hasher.update(data: data)
                byteCount += Int64(data.count)
            }

            return VeilFileIntegrityResult(
                fileName: url.lastPathComponent,
                byteCount: byteCount,
                sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined()
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as VeilFileIntegrityError {
            throw error
        } catch {
            throw VeilFileIntegrityError.unreadable
        }
    }

    static func compare(
        _ first: VeilFileIntegrityResult,
        _ second: VeilFileIntegrityResult
    ) -> VeilFileIntegrityComparison {
        first.byteCount == second.byteCount && first.sha256 == second.sha256
            ? .identical
            : .different
    }

    static func report(
        first: VeilFileIntegrityResult,
        second: VeilFileIntegrityResult? = nil
    ) -> String {
        var lines = [
            "VeilLink 文件完整性报告",
            reportBlock(label: "文件 A", result: first)
        ]
        if let second {
            lines.append(reportBlock(label: "文件 B", result: second))
            lines.append("比较：\(compare(first, second) == .identical ? "完全一致" : "不一致")")
        }
        return lines.joined(separator: "\n")
    }

    private static func reportBlock(label: String, result: VeilFileIntegrityResult) -> String {
        "\(label)：\(result.fileName)\n字节：\(result.byteCount)\nSHA-256：\(result.sha256)"
    }
}
