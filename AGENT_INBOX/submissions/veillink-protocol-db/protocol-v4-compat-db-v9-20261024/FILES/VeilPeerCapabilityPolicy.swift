import Foundation

/// A compatibility extension to authenticated Wire v4 acknowledgements.
/// This is advisory metadata, not a trust or authorization primitive.
enum VeilPeerCapabilityPolicy {
    static let schemaVersion = 1
    static let advertisedFeatureBits = 7 // bit 0: ACK; bit 1: control; bit 2: reliable control receipts
    static let recognizedFeatureBits = 7
    static let cacheLifetime: TimeInterval = 30 * 24 * 60 * 60

    static func validatedBits(schemaVersion: Int?, bits: Int?) -> Int? {
        guard schemaVersion == self.schemaVersion,
              let bits, bits >= 0, bits <= 1_048_575,
              bits & ~recognizedFeatureBits == 0 else { return nil }
        return bits
    }
}
