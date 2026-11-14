import CryptoKit
import Foundation

/// An optional, session-only composer affordance. This gate is a convenience
/// discoverability control, NOT an authentication or anti-analysis boundary.
/// Never log, persist, transmit or analytics-track the submitted access token.
enum VeilComposerOptionGate {
    // SHA-256 of the owner-selected 8 ASCII digits. The plaintext is not
    // embedded in the app; an 8-digit fixed token is still brute-forceable.
    private static let expectedDigest = "4e7acdb4943849f89d2e6f3cbab9025043e3831c77357e4ec1441bf3b0d096df"

    static func accepts(_ candidate: String) -> Bool {
        guard candidate.utf8.count == 8,
              candidate.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return false }
        let actual = SHA256.hash(data: Data(candidate.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return actual == expectedDigest
    }
}
