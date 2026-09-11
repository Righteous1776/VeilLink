import CryptoKit
import Foundation
import Security

enum PasswordKDF {
    static let minimumAcceptedIterations = 10_000
    static let maximumAcceptedIterations = 1_000_000
    static let maximumOutputByteCount = 64

    struct Verifier: Codable { let salt: Data; let iterations: Int; let digest: Data }

    static func makeVerifier(_ password: String, iterations: Int = 80_000) -> Verifier {
        precondition(iterations >= minimumAcceptedIterations && iterations <= maximumAcceptedIterations)
        let salt = randomData(count: 16)
        return Verifier(salt: salt, iterations: iterations, digest: derive(password: password, salt: salt, iterations: iterations, outputByteCount: 32))
    }

    static func verify(_ password: String, against verifier: Verifier) -> Bool {
        guard isSafeParameters(salt: verifier.salt, iterations: verifier.iterations, outputByteCount: verifier.digest.count, minimumIterations: minimumAcceptedIterations) else { return false }
        return constantTimeEqual(derive(password: password, salt: verifier.salt, iterations: verifier.iterations, outputByteCount: verifier.digest.count), verifier.digest)
    }

    static func isSafeParameters(salt: Data, iterations: Int, outputByteCount: Int, minimumIterations: Int) -> Bool {
        (16...64).contains(salt.count) && iterations >= minimumIterations && iterations <= maximumAcceptedIterations && (16...maximumOutputByteCount).contains(outputByteCount)
    }

    static func derive(password: String, salt: Data, iterations: Int, outputByteCount: Int) -> Data {
        precondition(iterations > 0 && iterations <= maximumAcceptedIterations)
        precondition(outputByteCount > 0 && outputByteCount <= maximumOutputByteCount)
        let key = SymmetricKey(data: Data(password.utf8))
        let blockCount = Int(ceil(Double(outputByteCount) / 32.0))
        var result = Data()
        for blockIndex in 1...blockCount {
            var input = salt
            let index = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: index) { input.append(contentsOf: $0) }
            var u = Data(HMAC<SHA256>.authenticationCode(for: input, using: key))
            var block = u
            if iterations > 1 {
                for _ in 2...iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for index in block.indices { block[index] ^= u[index] }
                }
            }
            result.append(block)
        }
        return result.prefix(outputByteCount)
    }

    static func randomData(count: Int) -> Data {
        precondition(count > 0 && count <= 4_096)
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        precondition(status == errSecSuccess)
        return Data(bytes)
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices { difference |= lhs[index] ^ rhs[index] }
        return difference == 0
    }
}
