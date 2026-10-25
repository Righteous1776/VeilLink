import Foundation

/// Input-shape triage only. Cryptographic, expiry and trust checks remain in
/// VeilRemotePairQRCodeCodec.decode and VeilRemotePairingCoordinator.
enum VeilPairCameraInputGate {
    static let prefix = "veillink://pair?v=1&d="
    static let maximumUTF8Bytes = 4_096

    static func accepts(_ candidate: String) -> Bool {
        guard candidate.hasPrefix(prefix),
              candidate.utf8.count >= prefix.utf8.count + 8,
              candidate.utf8.count <= maximumUTF8Bytes else { return false }

        // RemotePairingQRCodeCodec.encode uses unpadded base64url.
        let encoded = candidate.dropFirst(prefix.count)
        return encoded.utf8.allSatisfy { byte in
            (65...90).contains(byte) || (97...122).contains(byte) ||
            (48...57).contains(byte) || byte == 45 || byte == 95
        }
    }
}
