import Foundation
import CryptoKit

/// Fail-closed integrity check for a user-imported GGUF file.
/// Pin is derived from the exact 29,203,168-byte copy downloaded from the
/// owner's Google Drive. Publisher-side digest comparison is still pending.
enum Vertex35MModelIntegrityGate {
    static let expectedBytes: Int64 = 29_203_168
    static let expectedSHA256 = "c55c3c32740d5a283c505fc9f9b7313e4b3f0c98bb11efd21b651651d5cb36b5"

    enum Failure: Error, Equatable {
        case notARegularFile
        case wrongSize
        case badGGUFHeader
        case checksumMismatch
    }

    static func isGGUFv3Header(_ prefix: Data) -> Bool {
        guard prefix.count >= 8 else { return false }
        return Array(prefix.prefix(8)) == [0x47, 0x47, 0x55, 0x46, 0x03, 0x00, 0x00, 0x00]
    }

    /// Validate on a worker thread on EVERY attach/load.
    /// Do not trust URL-only caches: the file can be replaced at the same path.
    static func validate(url: URL) async throws {
        try await Task.detached(priority: .utility) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { throw Failure.notARegularFile }
            guard Int64(values.fileSize ?? -1) == expectedBytes else { throw Failure.wrongSize }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 8) ?? Data()
            guard isGGUFv3Header(header) else { throw Failure.badGGUFHeader }
            try handle.seek(toOffset: 0)

            var hasher = SHA256()
            while true {
                try Task.checkCancellation()
                let bytes = try handle.read(upToCount: 1_048_576) ?? Data()
                if bytes.isEmpty { break }
                hasher.update(data: bytes)
            }
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == expectedSHA256 else { throw Failure.checksumMismatch }
        }.value
    }
}
